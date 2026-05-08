# Puma 6 configuration.
#
# Key differences from Puma 5:
#   - nakayoshi_fork removed (Puma 6 forks more efficiently without it)
#   - wait_for_less_busy_worker available (helps under bursty load)
#   - lowlevel_error_handler signature changed (now receives env, ex, status)
#
# Tuning guide:
#   threads  — should equal RAILS_MAX_THREADS (default 3 in Rails 8, was 5 in 7)
#   workers  — set to CPU count; 0 means single-process with shared memory
#   WEB_CONCURRENCY — override workers via environment variable

threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

port ENV.fetch("PORT", 3000)
environment ENV.fetch("RAILS_ENV", "development")
pidfile ENV.fetch("PIDFILE", "tmp/pids/server.pid")

if ENV.fetch("RAILS_ENV", "development") == "production"
  # Number of Puma worker processes. Each worker gets its own Ruby GC.
  # Set WEB_CONCURRENCY to match CPU core count on the server.
  # preload_app! is used when workers == 1 (saves memory via CoW).
  worker_count = Integer(ENV.fetch("WEB_CONCURRENCY", 2))
  if worker_count > 1
    workers worker_count
  else
    preload_app!
  end
end

# Allow puma to be restarted by `bin/rails restart` command.
plugin :tmp_restart
