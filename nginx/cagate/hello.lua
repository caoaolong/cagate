local cagate = require("resty.cagate")
local json = require("cjson")
local token, payload, err = cagate.verify_token("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHBpcnkiOjE3MDQ0NDUzMTIsInVzZXJuYW1lIjoiY2FnYXRlIiwidXNlcl9pZCI6IkNCOUMxQTVCNjkxMDRGQjJCNDU3QTlDNzJBMzkyRDkwIiwicGhvbmUiOiIxMzczMDQwNzc1OCIsImVtYWlsIjoiZWFzb24xMDVjY0AxNjMuY29tIn0.zKhALyiN0m2JMwrtu1OQ50-YhDfrwROlPeH2Tq7Y7ac")
if not err then
    ngx.say(json.encode({
        token = token,
        payload = payload
    }))
end