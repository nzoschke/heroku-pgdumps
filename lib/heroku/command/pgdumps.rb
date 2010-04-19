module Heroku::Command
  class Pgdumps < BaseWithApp
    def list
      list = heroku.pgdumps(app)
      if list.size > 0
        list.each do |pgdump|
          space  = ' ' * [(18 - pgdump['name'].size),1].max
          state = pgdump['state'] == 'finished' ? '' : "(#{pgdump['state']})"
          display "#{pgdump['name']}" + space + "#{pgdump['size']} #{state}"
        end
      else
        display "#{app} has no pgdumps."
      end
    end
    alias :index :list

    def capture
      pgdump = heroku.pgdump_capture(app)
      display("Capturing pgdump #{pgdump['name']} of #{app}'s #{sprintf("%0.1f", pgdump['size'].to_f/(1024*1024))}MB database")
      last_progress = nil
      loop do
        sleep 1
        info = heroku.pgdump_info(app, pgdump['name'])
        progress = info['progress'].last
        if progress[0] != last_progress
          if info['progress'].length > 1
            display_progress(info['progress'][-2])
            display(' '*20 + "\n")
          end
          last_progress = progress[0]
        end
        display_progress(progress)
        break if info['state'] == 'complete'
      end
      display "\nDone."
    end

    def restore
      timeout = extract_option('--timeout', 30).to_i
      pgdump_name = args.first.strip.downcase rescue 'latest'
      pgdump = heroku.pgdump_restore(app, pgdump_name)
      display("Restoring #{pgdump['size']} byte pgdump...", false)
      begin
         Timeout::timeout(timeout) do
           loop do
             break if heroku.pgdump_complete?(app, pgdump['name'])
             display(".", false)
             sleep 1
           end
         end
         display " done"
       rescue Timeout::Error
         display "Timed Out! Check heroku info for status updates."
       end
    end

    def url
      pgdump_name = args.first.strip.downcase rescue 'latest'
      display heroku.pgdump_url(app, pgdump_name)
    end

    protected

    def display_progress(progress)
        display(sprintf("\r%-8s  ...  %s", progress[0].capitalize, progress[1]), false)
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
