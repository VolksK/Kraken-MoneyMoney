-- NOTE:
-- This file is a fork of https://github.com/aaronk6/Kraken-MoneyMoney
-- The filename is intentionally kept as "Kraken.lua" for compatibility.
--
-- Fork rationale:
-- - Prevent oversized Kraken Ticker requests that can lead to HTTP 520 errors
-- - Handle Kraken EOS → Vaulta (A) / AEUR transitions safely
--
-- Signing:
-- - This extension is currently UNSIGNED by MoneyMoney.
-- - MoneyMoney will show a warning on install; this is expected for community forks.

-- Inofficial Kraken Extension (www.kraken.com) for MoneyMoney
-- Fetches balances from Kraken API and returns them as securities
--
-- Username: Kraken API Key
-- Password: Kraken API Secret

-- ============================================================
-- BUG FIX 1: WebBanking{} block was missing entirely in fork.
--            Without it MoneyMoney cannot register the extension
--            → "Für diese Bank ist keine Web-Scraping-Unterstützung vorhanden."
-- ============================================================
WebBanking{
  version = 1.12,
  url = "https://api.kraken.com",
  description = "Fetch balances from Kraken API and list them as securities (fork: HTTP 520 fix + Vaulta/AEUR)",
  services = { "Kraken Account" },
}

-- ============================================================
-- BUG FIX 2: apiVersion, currency were missing (used throughout)
-- ============================================================
local apiKey
local apiSecret
local apiVersion = 0
local currency = "EUR"
local currencyName = "ZEUR"
local stakeSuffix = '.S'
local optInRewardsSuffix = '.M'
local bitcoin = 'XXBT'
local ethereum = 'XETH'
local market = "Kraken"
local accountName = "Balances"
local accountNumber = "Main"
local balances

local currencyNames = {

  -- crypto
  ADA  = "Cardano",
  APE  = "ApeCoin",
  ASTR = "Astar",
  ATOM = "Cosmos",
  AVAX = "Avalanche",
  BCH  = "Bitcoin Cash",
  DAI  = "Dai",
  DASH = "Dash",
  DOT  = "Polkadot",
  DOT28 = "Polkadot Fixed 28",
  EOS  = "EOS",
  A    = "Vaulta (A)",       -- EOS → Vaulta rename
  AEUR = "Vaulta (AEUR)",    -- DLT/Germany placeholder
  ETH2 = "Ethereum 2.0",
  ETHW = "Ethereum (PoW)",
  FTM  = "Fantom",
  GNO  = "Gnosis",
  LINK = "Chainlink",
  LUNA = "Terra Classic",
  LUNA2 = "Terra 2.0",
  MATIC = "Polygon",
  MINA = "Mina",
  QTUM = "QTUM",
  SHIB = "Shiba Inu",
  SOL  = "Solana",
  TRX  = "Tron",
  UNI  = "Uniswap",
  USDC = "USD Coin",
  USDT = "Tether (Omni Layer)",
  WBTC = "Wrapped Bitcoin",
  XETC = "Ethereum Classic",
  XETH = "Ethereum",
  XLTC = "Litecoin",
  XMLN = "Watermelon",
  XREP = "Augur",
  XTZ  = "Tezos",
  XXBT = "Bitcoin",
  XBT  = "Bitcoin",
  XXDG = "Dogecoin",
  XXLM = "Stellar Lumens",
  XXMR = "Monero",
  XXRP = "Ripple",
  XZEC = "Zcash",

  -- fiat
  ZCAD = "Canadian Dollar",
  ZEUR = "Euro",
  ZGBP = "Great British Pound",
  ZJPY = "Japanese Yen",
  ZUSD = "US Dollar"
}

function SupportsBank (protocol, bankCode)
  return protocol == ProtocolWebBanking and bankCode == "Kraken Account"
end

function InitializeSession (protocol, bankCode, username, username2, password, username3)
  apiKey = username
  apiSecret = password

  balances   = queryPrivate("Balance")
  assetPairs = queryPublic("AssetPairs")
  prices     = queryPublic("Ticker", { pair = table.concat(buildPairs(balances, assetPairs), ',') })
end

function ListAccounts (knownAccounts)
  local account = {
    name          = accountName,
    accountNumber = accountNumber,
    currency      = currency,
    portfolio     = true,
    -- ============================================================
    -- BUG FIX 3: must be a string, not a bare identifier
    -- ============================================================
    type          = "AccountTypePortfolio"
  }
  return {account}
end

function RefreshAccount (account, since)
  local s = {}

  for key, value in pairs(balances) do
    local pair, targetCurrency = getPairInfo(key)
    local name = resolveCurrencyName(key)

    -- AEUR is treated as 1:1 EUR for valuation (Vaulta/DLT placeholder)
    local isEurLike = (key == currencyName or key == currency or key == "AEUR")

    if prices[pair] ~= nil or isEurLike then
      local price = prices[pair] ~= nil and prices[pair]["b"][1] or 1

      if targetCurrency == bitcoin then
        price = price * prices[getPairInfo(bitcoin)]["b"][1]
      elseif targetCurrency == ethereum then
        price = price * prices[getPairInfo(ethereum)]["b"][1]
      end

      if tonumber(value) > 0 then
        s[#s+1] = {
          name     = name,
          market   = market,
          currency = nil,
          quantity = value,
          price    = price
        }
      end
    end
  end

  return {securities = s}
end

function EndSession ()
end

function resolveCurrencyName(key)
  local keyWithoutSuffix = removeSuffix(removeSuffix(key, stakeSuffix), optInRewardsSuffix)
  local isStaked = key ~= keyWithoutSuffix

  if isStaked and currencyNames[keyWithoutSuffix] ~= nil then
    return currencyNames[keyWithoutSuffix] .. ' (staked)'
  elseif currencyNames[key] then
    return currencyNames[key]
  end
  return key
end

function queryPrivate(method, request)
  if request == nil then request = {} end

  local path    = string.format("/%s/private/%s", apiVersion, method)
  local nonce   = string.format("%d", math.floor(MM.time() * 1000000))
  request["nonce"] = nonce
  local postData = httpBuildQuery(request)
  local apiSign  = MM.hmac512(MM.base64decode(apiSecret), path .. hex2str(MM.sha256(nonce .. postData)))
  local headers  = {}
  headers["API-Key"]  = apiKey
  headers["API-Sign"] = MM.base64(apiSign)

  connection = Connection()
  content    = connection:request("POST", url .. path, postData, nil, headers)
  json       = JSON(applyFillerWorkaround(content))
  return json:dictionary()["result"]
end

function queryPublic(method, request)
  local path        = string.format("/%s/public/%s", apiVersion, method)
  local queryParams = ""

  if request ~= nil and next(request) ~= nil then
    queryParams = "?" .. httpBuildQuery(request)
  end

  local content = connection:request("GET", url .. path .. queryParams, "")
  local json    = JSON(applyFillerWorkaround(content))
  return json:dictionary()["result"]
end

function applyFillerWorkaround(content)
  local fixVersion = '2.3.4'
  if versionCompare(MM.productVersion, fixVersion) == -1 then
    print("Adding filler to work around bug in product versions earlier than " .. fixVersion)
    return '{"filler":"' .. string.rep('x', 2048) .. '",' .. string.sub(content, 2)
  end
  return content
end

function hex2str(hex)
  return (hex:gsub("..", function(byte)
    return string.char(tonumber(byte, 16))
  end))
end

function httpBuildQuery(params)
  local str = ''
  for key, value in pairs(params) do
    str = str .. key .. "=" .. value .. "&"
  end
  return str.sub(str, 1, -2)
end

function buildPairs(balances, assetPairs)
  local defaultPair = bitcoin .. currencyName  -- XXBTZEUR
  local wanted = {}
  local t = {}

  local function add(p)
    if p ~= nil and wanted[p] == nil then
      wanted[p] = true
      table.insert(t, p)
    end
  end

  -- Always include default pair for BTC/ETH→EUR conversions
  add(defaultPair)

  -- Only request ticker pairs for assets we actually hold (avoids HTTP 520)
  for asset, amount in pairs(balances) do
    local value = tonumber(amount)
    if value ~= nil and value > 0 then
      -- EUR-like assets are 1:1 — no ticker needed
      if asset ~= currencyName and asset ~= currency and asset ~= "AEUR" then
        local pair, targetCurrency = getPairInfo(asset)
        add(pair)

        if targetCurrency == bitcoin then
          add(bitcoin .. currencyName)
        elseif targetCurrency == ethereum then
          add(ethereum .. currencyName)
        end
      end
    end
  end

  return t
end

function getPairInfo(base)
  base = removeSuffix(base, stakeSuffix)
  base = removeSuffix(base, optInRewardsSuffix)

  if base == 'XBT' then base = 'XXBT' end

  local opt1 = base .. currency
  local opt2 = base .. currencyName
  local opt3 = base .. bitcoin
  local opt4 = base .. ".SETH"

  if     assetPairs[opt1] ~= nil then return opt1, currency
  elseif assetPairs[opt2] ~= nil then return opt2, currencyName
  elseif assetPairs[opt3] ~= nil then return opt3, bitcoin
  elseif assetPairs[opt4]        then return opt4, ethereum
  end

  return nil
end

function removeSuffix(str, suffix)
  if ends_with(str, suffix) then
    return str:sub(1, -#suffix-1)
  end
  return str
end

function versionCompare(version1, version2)
  local v1 = split(version1, '.')
  local v2 = split(version2, '.')
  if #v1 ~= #v2 then error("version1 and version2 need to have the same number of fields") end
  for i = 1, #v1 do
    local n1 = tonumber(v1[i])
    local n2 = tonumber(v2[i])
    if     n1 > n2 then return  1
    elseif n1 < n2 then return -1
    end
  end
  return 0
end

function split(str, delimiter)
  local t, ll = {}, 0
  if #str == 1 then return {str} end
  while true do
    local l = string.find(str, delimiter, ll, true)
    if l ~= nil then
      table.insert(t, string.sub(str, ll, l-1))
      ll = l + 1
    else
      table.insert(t, string.sub(str, ll))
      break
    end
  end
  return t
end

function ends_with(str, ending)
  return ending == "" or str:sub(-#ending) == ending
end
