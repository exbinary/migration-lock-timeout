module MigrationLockTimeout
  module LockManager

    def migrate(direction)
      timeout_disabled = self.class.disable_lock_timeout
      time = self.class.lock_timeout_override ||
        MigrationLockTimeout.try(:config).try(:default_timeout)

      if !timeout_disabled && direction == :up && time
        if disable_ddl_transaction
          with_session_lock_timeout(time) { super }
        else
          with_local_lock_timeout(time) { super }
        end
      else
        super
      end
    end

    def safety_assured?
      if defined?(StrongMigrations)
        safety_assured { yield }
      else
        yield
      end
    end

    def with_local_lock_timeout(timeout)
      safety_assured? { execute "SET LOCAL lock_timeout = '#{timeout}s'" }
      yield
    end

    def with_session_lock_timeout(timeout)
      stashed_timeout = suppress_messages { current_lock_timeout_setting }
      begin
        safety_assured? { execute "SET lock_timeout = '#{timeout}s'" }
        yield
      ensure
        safety_assured? { execute "SET lock_timeout = '#{stashed_timeout}'" }
      end
    end

    def current_lock_timeout_setting
      result = exec_query(
        "select setting from pg_settings where name = 'lock_timeout'"
      )
      result[0]['setting']
    end
  end
end
