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
      timeout = extract_option('--timeout', 30).to_i
      pgdump = heroku.pgdump_capture(app)
      display("Capturing a pgdump of #{app}'s #{pgdump['size']} byte database...", false)
      begin
        Timeout::timeout(timeout) do
          loop do
            break if heroku.pgdump_complete?(app, pgdump['name'])
            display(".", false)
            sleep 1
          end
        end
        display " done"
        pgdump = heroku.pgdump_info(app, pgdump['name'])
        display "The compressed pgdump is #{pgdump['size']} bytes and named #{pgdump['name']}"
      rescue Timeout::Error
        display "Timed Out! Check heroku info for status updates."
      end
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
      Help.group 'Pgdumps' do |group|
        group.command 'pgdumps',                      'list pgdumps for the app'
        group.command 'pgdumps:capture',              'capture a dump of the app\'s postgres database'
        group.command 'pgdumps:restore <name>',       'restore the app\'s postgres database from a pgdump'
        group.command 'pgdumps:restore <url>',        'restore the app\'s postgres database from an arbitrary URL'
        group.command 'pgdumps:url [<name>]',         'get a URL for a pgdump'
      end
  end
end
