begin
  require 'redmine'
  require 'haltr'

  RAILS_DEFAULT_LOGGER.info 'Starting haltr plugin'

  Date::DATE_FORMATS[:ddmmyy] = "%d%m%y"

  Redmine::Plugin.register :haltr do
    name 'haltr'
    author 'Ingent'
    description 'Hackers dont do books'
    version '0.1'
    settings :default => {
      'company_name' => 'Ingent Grup Systems, SL',
      'company_tax_id' => 'B63354724',
      'company_address' => '',
      'company_locality' => '',
      'company_postal_code' => '',
      'company_region' => '',
      'company_website' => '',
      'company_email' => '',
      'company_bank_account' => '',
      'company_logo_url' => ''
    },
    :partial => 'haltradmin/settings'

    project_module :haltr do
      permission :general_use,
        { :clients  => [:index, :new, :edit, :create, :update, :destroy],
          :people   => [:index, :new, :edit, :create, :update, :destroy],
          :invoices => [:index, :for_client, :new, :edit, :create, :update, :destroy, :showit, :pdf, :template, :mark_sent, :mark_closed, :mark_not_sent],
          :invoice_templates => [:index, :new, :edit, :create, :update, :destroy, :showit],
          :tasks    => [:index, :create_more, :automator, :n19, :n19_done, :report] },
        :require => :member
    end

    menu :project_menu, :haltr, { :controller => 'clients', :action => 'index' }, :caption => 'Haltr'

  end

rescue MissingSourceFile
  RAILS_DEFAULT_LOGGER.info 'Warning: not running inside Redmine'
end