local mysql = require("resty.mysql")
local cagate = ngx.shared.cagate
local db, err = mysql:new()
if (err == nil)
then
    ngx.say("New OK!<br/>")
    local opts = {}
    opts["user"] = "root"
    opts["password"] = "calong"
    opts["host"] = "172.17.0.3"
    opts["port"] = 3306
    opts["database"] = "test"
    opts["charset"] = "utf8"
    opts["ssl"] = true
    local ok, err, errcode, sqlstate = db:connect(opts)
    if (err == nil)
    then
        ngx.say("Connect OK!<br/>")
        ngx.say("MySQL Server Version: " .. db:server_ver() .. "<br/>")
        ngx.say(cagate:get("name"))
        db:close()
    end
end