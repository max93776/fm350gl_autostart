module("luci.controller.myapp", package.seeall)

function index()
    entry({"admin", "status", "myapp"}, template("myapp_status"), _("My ci.App Status"), 90)
    entry({"admin", "status", "myapp", "get_at_command"}, call("get_at_command"), nil)
end

function get_at_command()
    local at_command_output = luci.sys.exec("timeout 3 /root/autostart/at_commander at+cesq | grep -oE '[0-9]+' | sed '1d' | tr '\n' ' '")
    local numbers = {}

    for number in at_command_output:gmatch("%d+") do
        table.insert(numbers, tonumber(number))  -- In das Array einfügen
    end

    luci.http.prepare_content("application/json")
    luci.http.write_json({result = numbers})  -- Rückgabe der Zahlen als Array

    luci.sys.exec("logger Modem-Status-luci: AT_Command_Output: " .. at_command_output)
end

