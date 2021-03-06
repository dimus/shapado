ActionController::Routing::Routes.draw do |map|
  map.devise_for :users, :path_names => { :sign_in => 'login', :sign_out => 'logout' }

  map.change_language_filter '/change_language_filter', :controller => 'welcome', :action => 'change_language_filter'
  map.register '/register', :controller => 'users', :action => 'create'
  map.signup '/signup', :controller => 'users', :action => 'new'
  map.moderate '/moderate', :controller => 'admin/moderate', :action => 'index'
  map.ban '/moderate/ban', :controller => 'admin/moderate', :action => 'ban'
  map.facts '/facts', :controller => 'welcome', :action => 'facts'
  map.plans '/plans', :controller => 'doc', :action => 'plans'
  map.chat '/chat', :controller => 'doc', :action => 'chat'
  map.feedback '/feedback', :controller => 'welcome', :action => 'feedback'
  map.send_feedback '/send_feedback', :controller => 'welcome', :action => 'send_feedback'
  map.settings '/settings', :controller => 'users', :action => 'edit'
  map.tos '/tos', :controller => 'doc', :action => 'tos'
  map.privacy '/privacy', :controller => 'doc', :action => 'privacy'
  map.resources :users, :member => { :change_preferred_tags => :any,
                                     :follow => :any, :unfollow => :any},
                        :collection => {:autocomplete_for_user_login => :get}
  map.resource :session
  map.resources :ads
  map.resources :adsenses
  map.resources :adbards
  map.resources :badges

  def build_questions_routes(router, options ={})
    router.with_options(options) do |route|
      route.resources :questions, :collection => {:tags => :get,
                                                  :unanswered => :get,
                                                  :related_questions => :get},
                                :member => {:solve => :get,
                                            :unsolve => :get,
                                            :flag => :get,
                                            :favorite => :any,
                                            :unfavorite => :any,
                                            :watch => :any,
                                            :unwatch => :any,
                                            :history => :get,
                                            :diff => :get,
                                            :rollback => :put,
                                            :move => :get,
                                            :move_to => :put} do |questions|
        questions.resources :answers, :member => {:flag => :get,
                                                  :history => :get,
                                                  :diff => :get,
                                                  :rollback => :put}
      end
    end
  end

  build_questions_routes(map)
  build_questions_routes(map, :path_prefix => '/:language', :name_prefix => "with_language_") #deprecated route

  map.resources :groups, :member => {:accept => :get,
                                     :close => :get,
                                     :allow_custom_ads => :get,
                                     :disallow_custom_ads => :get,
                                     :logo => :get,
                                     :favicon => :get,
                                     :css => :get},
                          :collection => { :autocomplete_for_group_slug => :get}


  map.resources :comments
  map.resources :votes
  map.resources :flags

  map.resources :widgets, :member => {:move => :post}, :path_prefix => "/manage"
  map.resources :members, :path_prefix => "/manage"
  map.manage '/manage', :controller => 'admin/manage', :action => 'properties'

  map.with_options :controller => 'admin/manage', :name_prefix => "manage_",
                   :path_prefix => "/manage" do |manage|
    manage.properties '/properties', :action => 'properties'
    manage.content '/content', :action => 'content'
    manage.theme '/theme', :action => 'theme'
    manage.actions '/actions', :action => 'actions'
    manage.stats '/stats', :action => 'stats'
    manage.reputation '/reputation', :action => 'reputation'
    manage.domain '/domain', :action => 'domain'
  end

  map.search '/search.:format', :controller => "searches", :action => "index"
  map.about '/about', :controller => "groups", :action => "show"
  map.root :controller => "welcome"

  map.connect ':controller/:action/:id'
  map.connect ':controller/:action/:id.:format'
end
