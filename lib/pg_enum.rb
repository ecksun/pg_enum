if defined?(::Rails::Railtie)
  class PgEnumRailtie < Rails::Railtie
    initializer 'pg_enum.initialize', :after => 'active_record.initialize_database' do |app|
      ActiveSupport.on_load :active_record do
        require 'pg_enum/active_record'
      end
    end
  end
end

