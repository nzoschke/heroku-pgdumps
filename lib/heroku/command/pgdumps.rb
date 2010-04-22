module Heroku::Command
  class Pgdumps < BaseWithApp
    def list
      list = heroku.pgdumps(app)
      rows = [['Pgdump', 'Size', 'Status']]
      list.each do |pgdump|
        rows << [pgdump['name'], human_size(pgdump['size']), pgdump['state']]
      end
      print_table(rows, :header => true)
      display "#{app} has no pgdumps." if list.size == 0
    end
    alias :index :list

    def capture
      pgdump = heroku.pgdump_capture(app)
      display("Capturing pgdump #{pgdump['name']} of #{app}'s #{sprintf("%0.1f", pgdump['size'].to_f/(1024*1024))}MB database")
      monitor_progress(pgdump['name'])
    rescue PgdumpError
      raise CommandFailed, "Internal server error"
    end

    def restore
      name = args.first.strip rescue 'latest'
      pgdump = heroku.pgdump_restore(app, name)
      display("Restoring #{sprintf("%0.1f", pgdump['size'].to_f/(1024*1024))}MB pgdump #{pgdump['name']} to #{app}")
      monitor_progress(pgdump['name'])
    rescue PgdumpError
      raise CommandFailed, "Internal server error - your existing database has not been affected"
    end

    def url
      pgdump_name = args.first.strip rescue 'latest'
      display heroku.pgdump_url(app, pgdump_name)
    end

    protected

    class PgdumpError < RuntimeError; end

    def monitor_progress(pgdump_name)
      last_progress = nil
      spinner = 0
      loop do
        sleep 1

        info = heroku.pgdump_info(app, pgdump_name)
        progress = info['progress'].last

        if progress and progress[0] != last_progress
          show = false
          info['progress'].each do |row|
            next if row == progress
            show = true if last_progress == row[0] or last_progress.nil?
            if show
              display_progress(row)
              display("\n")
            end
          end
          last_progress = progress[0]
        end

        if ['captured', 'restored'].member? info['state']
          display_progress(progress)
          break
        end

        if info['state'] == 'error'
          display_progress(progress)
          display("\n")
          raise PgdumpError
        end

        spinner = display_progress(progress, spinner)
      end

      display "\nComplete."
    end

    def display_progress(progress, spinner=nil)
      return spinner unless progress

      display(sprintf("\r\e[2K%-8s  ...  %s", progress[0].capitalize, progress[1]), false)

      if spinner
        spinner = (spinner + 1) % spinner_chars.length
        display(" " + spinner_chars[spinner], false)
        spinner
      end
    end

    def spinner_chars
      %w(/ - \\ |)
    end

    def human_size(bytes)
       units = %w{B KB MB GB TB}
       bytes = bytes.to_i
       return '0B' unless bytes > 0
       e = (Math.log(bytes)/Math.log(1024)).floor
       s = "%.2f" % (bytes.to_f / 1024**e)
       s.sub(/\.?0*$/, units[e])
    end

    def print_table(rows, options={})
      widths = [0] * rows.first.size
      rows.each { |row|
        row.each_with_index { |cell, i|
          widths[i] = [widths[i], cell.to_s.size].max
        }
      }

      rows.insert(1, widths.collect {|w| '-' * w}) if options[:header]

      rows.each { |row|
        r = ""
        row.each_with_index { |cell, i|
          r += cell.to_s + ' ' * (widths[i] - cell.to_s.size + 3)
        }
        display r
      }
    end

    Help.group 'Pgdumps' do |group|
      group.command 'pgdumps',                      'list pgdumps for the app'
      group.command 'pgdumps:capture',              'capture a dump of the app\'s postgres database'
      group.command 'pgdumps:restore <name>',       'restore the app\'s postgres database from a pgdump'
      group.command 'pgdumps:restore <url>',        'restore the app\'s postgres database from an arbitrary URL'
      group.command 'pgdumps:url [<name>]',         'get a URL for a pgdump'
    end
  end
end
