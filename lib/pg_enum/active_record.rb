module ActiveRecord

  class SchemaDumper

    alias __enum_tables tables

    def tables(stream)
      @connection.enum_types.each do |typename, values|
        stream.puts "  create_enum #{typename.inspect}, :values => #{values.inspect}"
      end
      stream.puts
      __enum_tables(stream)
    end

  end

  class Migration

    class CommandRecorder

      def create_enum(*args)
        record(:create_enum, args)
      end

      def drop_enum(*args)
        record(:drop_enum, args)
      end

      def invert_create_enum(args)
        [:drop_enum, [args.first]]
      end

    end

  end

  module ConnectionAdapters

    # TODO: implement commandrecorder reversibility
    #

    module SchemaStatements

      def create_enum(enum_name, options = {})
        if options[:force] && enum_types.has_key?(enum_name)
          drop_enum(enum_name)
        end

        create_enum_sql = "CREATE TYPE #{enum_name} AS ENUM ('"
        create_enum_sql << options[:values].join("','")
        create_enum_sql << "')"
        enum_types[enum_name.intern] = options[:values].map(&:intern)
        execute create_enum_sql
      end

      def drop_enum(enum_name)
        execute "DROP TYPE #{enum_name}"
      end

    end

    class TableDefinition

      alias __enum_method_missing method_missing

      def method_missing(symbol, *args)
        if @base.enum_types.has_key?(symbol)
          options = args.extract_options!
          column(args[0], symbol, options)
        else
          __enum_method_missing(symbol, *args)
        end
      end

    end

    class PostgreSQLColumn < Column

      alias __enum_klass klass

      def klass
        if is_enum?(type)
          Symbol
        else
          __enum_klass
        end
      end

      alias __enum_simplified_type simplified_type

      def simplified_type(field_type)
        if is_enum?(field_type.intern)
          field_type.intern
        else
          __enum_simplified_type(field_type)
        end
      end

      alias __enum_type_cast type_cast

      def type_cast(value)
        if is_enum?(type)
          value.try(:intern)
        else
          __enum_type_cast(value)
        end
      end

      alias __enum_type_cast_code type_cast_code

      def type_cast_code(var_name)
        if is_enum?(type)
          "#{var_name}.try(:intern)"
        else
          __enum_type_cast_code(var_name)
        end
      end

      private

      def is_enum?(enum_type)
        Base.connection.enum_types.has_key?(enum_type)
      end

    end
  
    class PostgreSQLAdapter < AbstractAdapter

      alias __enum_native_database_types native_database_types

      def native_database_types
        enums = Hash[enum_types.map{|typname,values| [typname, {:name => typname}]}]
        __enum_native_database_types.merge(enums)
      end


      def enum_types
        @enum_types ||= get_enum_types
      end

      private

      def get_enum_types
        enum_hash = {}
        fetch_enum_rows.values.each do |type, label|
          (enum_hash[type.intern] ||= []) << label.intern
        end
        enum_hash
      end

      def fetch_enum_rows
        execute <<-SQL
          SELECT t.typname, e.enumlabel
            FROM   pg_catalog.pg_type t 
            JOIN   pg_catalog.pg_namespace n ON n.oid = t.typnamespace 
            JOIN   pg_catalog.pg_enum e ON t.oid = e.enumtypid  
            ORDER BY t.typname, e.enumsortorder;
        SQL
      end
    
    end
  end
end
