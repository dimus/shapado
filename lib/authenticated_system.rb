module AuthenticatedSystem
  include OpenIdAuthentication

  def self.included(controller)
    controller.class_eval do
      alias_method :logged_in?, :user_signed_in?
      helper_method :logged_in?
    end
  end

  protected
  # Attempts to authenticate the given scope by running authentication hooks,
  # but does not redirect in case of failures. Overrode from devise.
  def authenticate(scope)
    user = if using_open_id?
      user = open_id_authentication(params["openid.identity"], false)
      if user
        warden.set_user(user, :scope => scope)
      end
      user
    else
      warden.authenticate(:scope => scope)
    end

    if user
      user.localize(request.remote_ip)
      user.logged!(current_group)
      check_draft
    end

    user
  end

  # Attempts to authenticate the given scope by running authentication hooks,
  # redirecting in case of failures. Overrode from devise.
  def authenticate!(scope)
    user = if using_open_id?
      open_id_authentication(params["openid.identity"], true)
    else
      warden.authenticate!(:scope => scope)
    end

    if user
      user.localize(request.remote_ip)
      user.logged!(current_group)
      check_draft
    end

    user
  end

  def login_required
    respond_to do |format|
      format.js do
        if warden.authenticate(:scope => :user).nil?
          return render(:json => {:message => t("global.please_login"),
                                            :success => false,
                                            :status => :unauthenticate}.to_json)
        end
      end
      format.any { warden.authenticate!(:scope => :user) }
    end
  end


  private

  def open_id_authentication(identity_url, redirect_if_failed = true)
    failed = true
    error_message = nil
    authenticate_with_open_id(
      identity_url,
      :required => [:nickname,
                    :email,
                    'http://axschema.org/contact/email' ]
    ) do |result, identity_url, registration|
      failed = !result.successful?
      if !failed
        if identity_url =~ %r{//www.google.com}
          identity_url = "http://google_id_#{registration["http://axschema.org/contact/email"][0]}"
        end

        if @user = User.find_by_identity_url(identity_url)
          @user
        elsif (@user = create_openid_user(registration, identity_url)) && @user.valid?
          @user
        else
          failed = true
          error_message = result.message
        end
      elsif redirect_if_failed
        if error_message.blank? && @user
          error_message = @user.errors.full_messages.join(", ")
        end

        redirect_to new_user_session_path
      end
    end

    @user
  end

  def create_openid_user(registration, identity_url)
    google_id = false
    if identity_url =~ /google_id_/
      google_id = true
      registration["email"] = registration["http://axschema.org/contact/email"][0]
      registration["nickname"] = registration["email"].split(/@/)[0]
    end

    @user = User.find_by_login(registration["nickname"]) # FIXME: find by email?
    if registration["nickname"].blank? || @user
      if google_id
        login = registration["nickname"]+"_google_id"
      else
        o =  [('a'..'z'),('A'..'Z')].map{|i| i.to_a}.flatten
        string  =  (0..50).map{ o[rand(o.length)]  }.join
        login = URI::parse(identity_url).host.gsub('.','')+URI::parse(identity_url).
        path.gsub('.','').gsub('/','')
      end
    else
      login = registration["nickname"]
    end

    email = registration["email"]

    @user = User.create(:login => login, :email => email, :identity_url=> identity_url)
    if !@user.valid?
      Rails.logger.error("FAILED OPENID LOGIN WITH: #{identity_url} #{registration.inspect}")
      Rails.logger.error(">>>> #{@user.errors.full_messages.join(", ")}")
    end

    @user
  end

  def check_draft
    if draft_id = session[:draft]
      session[:draft] = nil
      draft = Draft.find(draft_id)
      if !draft.nil?
        if !draft.question.nil?
          question = draft.question
          question.user = current_user
          session[:"user.return_to"] = new_question_path(:question => {:body => question.body, :language => question.language,
                                        :title => question.title, :tags => question.tags})
        elsif !draft.answer.nil?
          answer = draft.answer
          answer.user = current_user
          session[:"user.return_to"] = question_path(answer.question, :answer => {:body => answer.body},
                                              :anchor => "to_answer")
        end
        draft.destroy
      end
    end
  end

end
