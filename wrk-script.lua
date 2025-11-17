-- wrk Lua script for Payment Consumer API
wrk.method = "POST"
wrk.body   = '{"customerId":"CUST001","fromAccount":"ACC001","toAccount":"ACC002","amount":100.50,"currency":"USD","paymentType":"DOMESTIC_PAYMENT","description":"Payment to friend"}'
wrk.headers["Content-Type"] = "application/json"

-- Initialize response stats
responses = {}

-- Called for each response
function response(status, headers, body)
    responses[status] = (responses[status] or 0) + 1
end

-- Called when test is done
function done(summary, latency, requests)
    io.write("\n========================================\n")
    io.write("Response Status Codes:\n")
    io.write("========================================\n")
    for status, count in pairs(responses) do
        io.write(string.format("  %d: %d responses\n", status, count))
    end
    io.write("\n")
end
