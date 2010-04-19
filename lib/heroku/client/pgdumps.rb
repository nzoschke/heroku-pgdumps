class Heroku::Client
  def pgdumps(app_name)
    JSON.parse(get("/apps/#{app_name}/pgdumps", :accept => 'application/json'))
  end

  def pgdump_capture(app_name)
    JSON.parse(post("/apps/#{app_name}/pgdumps", :accept => 'application/json'))
  end

  def pgdump_restore(app_name, pgdump_name)
    JSON.parse(put("/apps/#{app_name}/pgdumps", {:name => pgdump_name}, :accept => 'application/json'))
  end

  def pgdump_info(app_name, pgdump_name)
    JSON.parse(get("/apps/#{app_name}/pgdumps/#{pgdump_name}", :accept => 'application/json'))
  end

  def pgdump_complete?(app_name, pgdump_name)
    ['finished', 'error'].include? pgdump_info(app_name, pgdump_name)['state']
  end

  def pgdump_url(app_name, pgdump_name)
    JSON.parse(get("/apps/#{app_name}/pgdumps/#{pgdump_name || 'latest'}?temp_url=true", :accept => 'application/json'))['temp_url']
  end
end
