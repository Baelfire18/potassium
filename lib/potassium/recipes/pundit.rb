class Recipes::Pundit < Rails::AppBuilder
  def ask
    if get(:authentication).present?
      use_pundit = answer(:pundit) { Ask.confirm("Do you want to use Pundit for authorization?") }
      set(:authorization, use_pundit)
    end
  end

  def create
    if selected?(:authorization)
      run_pundit_installer
      recipe = self

      if selected?(:admin_mode)
        after(:admin_install) do
          recipe.install_admin_pundit
        end
      end
    end
  end

  def install
    run_pundit_installer

    active_admin = load_recipe(:admin)
    install_admin_pundit if active_admin.installed?
  end

  def installed?
    gem_exists?(/pundit/)
  end

  def install_admin_pundit
    configure_active_admin_initializer
    copy_policies
  end

  private

  def configure_active_admin_initializer
    config_active_admin_option("authorization_adapter", "ActiveAdmin::PunditAdapter")
    config_active_admin_option("pundit_default_policy", "'BackOffice::DefaultPolicy'")
    config_active_admin_option("pundit_policy_namespace", ":back_office")
  end

  def copy_policies
    copy_policy("default_policy")
    copy_policy("admin_user_policy")
    copy_policy("page_policy", "active_admin")
    copy_policy("comment_policy", "active_admin")
  end

  def config_active_admin_option(option, value)
    initializer = "config/initializers/active_admin.rb"
    gsub_file initializer, /# config\.#{option} =[^\n]+\n/ do
      "config.#{option} = #{value}\n"
    end
  end

  def copy_policy(policy_name, model_namespace = nil)
    destination_path = [model_namespace, policy_name].compact.join("/")
    template(
      "../assets/active_admin/policies/#{policy_name}.rb",
      "app/policies/back_office/#{destination_path}.rb"
    )
  end

  def run_pundit_installer
    gather_gem 'pundit'

    after(:gem_install) do
      application_controller = "app/controllers/application_controller.rb"
      gsub_file application_controller, "protect_from_forgery" do
        "include Pundit\n  protect_from_forgery"
      end
      generate "pundit:install"
      add_readme_section :internal_dependencies, :pundit
    end
  end
end
