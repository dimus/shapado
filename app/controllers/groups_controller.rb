class GroupsController < ApplicationController
  skip_before_filter :check_group_access, :only => [:logo, :css, :favicon]
  before_filter :login_required, :except => [:index, :show, :logo, :css, :favicon]
  before_filter :check_permissions, :only => [:edit, :update, :close]
  before_filter :moderator_required , :only => [:accept, :destroy]
  # GET /groups
  # GET /groups.xml
  def index
    case params.fetch(:tab, "actives")
      when "actives"
        @state = "active"
      when "pendings"
        @state = "pending"
    end

    @groups = Group.paginate(:per_page => 15,
                             :page => params[:page],
                             :state => @state,
                             :order => "created_at desc",
                             :private => false)

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @groups }
    end
  end

  # GET /groups/1
  # GET /groups/1.xml
  def show
    @active_subtab = "about"

    if params[:id]
      @group = Group.find_by_slug_or_id(params[:id])
    else
      @group = current_group
    end
    @comments = @group.comments.paginate(:page => params[:page].to_i,
                                         :per_page => params[:per_page] || 10 )

    @comment = Comment.new


    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @group }
    end
  end

  # GET /groups/new
  # GET /groups/new.xml
  def new
    @group = Group.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @group }
    end
  end

  # GET /groups/1/edit
  def edit
  end

  # POST /groups
  # POST /groups.xml
  def create
    @group = Group.new
    @group.safe_update(%w[name legend description default_tags subdomain logo forum
                          custom_favicon language theme], params[:group])

    if custom_css = params[:group][:custom_css]
      @group.custom_css = StringIO.new(custom_css)
    end

    @group.safe_update(%w[isolate domain private], params[:group]) if current_user.admin?

    @group.owner = current_user
    @group.state = "active"

    @group.widgets << TopGroupsWidget.create(:position => 0)
    @group.widgets << TopUsersWidget.create(:position => 1)
    @group.widgets << BadgesWidget.create(:position => 2)

    respond_to do |format|
      if @group.save
        @group.add_member(current_user, "owner")
        flash[:notice] = I18n.t("groups.create.flash_notice")
        format.html { redirect_to(domain_url(:custom => @group.domain, :controller => "admin/manage", :action => "properties")) }
        format.xml  { render :json => @group.to_json, :status => :created, :location => @group }
      else
        format.html { render :action => "new" }
        format.xml  { render :json => @group.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /groups/1
  # PUT /groups/1.xml
  def update
    logo = params[:group][:logo]
    if logo && logo.respond_to?(:original_filename)
      if logo.original_filename =~ /\.(\w+)$/
        @group.logo_ext = $1
      end
    end

    @group.safe_update(%w[name legend description default_tags subdomain logo forum
                          custom_favicon language theme reputation_rewards reputation_constrains], params[:group])
    if custom_css = params[:group][:custom_css]
      @group.custom_css = StringIO.new(custom_css)
    end
    @group.safe_update(%w[isolate domain private has_custom_analytics has_custom_html has_custom_js], params[:group]) if current_user.admin?
    @group.safe_update(%w[analytics_id analytics_vendor], params[:group]) if @group.has_custom_analytics
    @group.safe_update(%w[footer _head _question_help _question_prompt head_tag], params[:group]) if @group.has_custom_html

    respond_to do |format|
      if @group.save
        flash[:notice] = 'Group was successfully updated.' # TODO: i18n
        format.html { redirect_to(params[:source] ? params[:source] : group_path(@group)) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @group.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /groups/1
  # DELETE /groups/1.xml
  def destroy
    @group = Group.find_by_slug_or_id(params[:id])
    @group.destroy

    respond_to do |format|
      format.html { redirect_to(groups_url) }
      format.xml  { head :ok }
    end
  end

  def accept
    @group = Group.find_by_slug_or_id(params[:id])
    @group.has_custom_ads = true if params["has_custom_ads"] == "true"
    @group.state = "active"
    @group.save
    redirect_to group_path(@group)
  end

  def close
    @group.state = "closed"
    @group.save
    redirect_to group_path(@group)
  end

  def logo
    @group = Group.find_by_slug_or_id(params[:id], :select => [:_logo, :logo_ext])
    send_data(@group.logo.try(:read), :filename => "logo.#{@group.logo_ext}",  :disposition => 'inline')
  end

  def css
    @group = Group.find_by_slug_or_id(params[:id], :select => [:_custom_css])
    if @group._custom_css
      send_data(@group.custom_css.read, :filename => "custom_theme.css", :type => "text/css")
    else
      render :text => ""
    end
  end

  def favicon
    @group = Group.find_by_slug_or_id(params[:id], :select => [:_custom_favicon])
    send_data(@group.custom_favicon.read, :filename => "favicon.ico")
  end

  def autocomplete_for_group_slug
    @groups = Group.all( :limit => params[:limit] || 20,
                         :fields=> 'slug',
                         :slug =>  /.*#{params[:prefix].downcase.to_s}.*/,
                         :order => "slug desc",
                         :state => "active")

    respond_to do |format|
      format.json {render :json=>@groups}
    end
  end

  def allow_custom_ads
    if current_user.admin?
      @group = Group.find_by_slug_or_id(params[:id])
      @group.has_custom_ads = true
      @group.save
    end
    redirect_to groups_path
  end

  def disallow_custom_ads
    if current_user.admin?
      @group = Group.find_by_slug_or_id(params[:id])
      @group.has_custom_ads = false
      @group.save
    end
    redirect_to groups_path
  end

  protected
  def check_permissions
    @group = Group.find_by_slug_or_id(params[:id])

    if @group.nil?
      redirect_to groups_path
    elsif !current_user.owner_of?(@group)
      flash[:error] = t("global.permission_denied")
      redirect_to group_path(@group)
    end
  end
end
