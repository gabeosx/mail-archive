-- imapfilter configuration for pruning old emails on remote IMAP
-- Reads credentials and policy from environment variables

local env = os.getenv

local USER = env('EMAIL_USER')
local PASS = env('EMAIL_PASS') or ''
local HOST = env('IMAP_HOST')
local PORT = tonumber(env('IMAP_PORT') or '993')
local PRUNE_DAYS = tonumber(env('PRUNE_DAYS') or '365')
local DRY_RUN = (env('DRY_RUN') or 'false') == 'true'

if not USER or not HOST then
  print('Error: EMAIL_USER and IMAP_HOST must be set in environment')
  os.exit(1)
end

-- Prefer reading password from Docker secret if present; allow override via EMAIL_PASS_FILE
local secret_path = env('EMAIL_PASS_FILE') or '/run/secrets/imap_password'
local f = io.open(secret_path, 'r')
if f ~= nil then
  local content = f:read('*a')
  if content ~= nil then
    -- Trim trailing newlines/spaces
    PASS = (content:gsub('%s+$', ''))
  end
  f:close()
end

-- Build account
options = {
  timeout = 120,
  ssl = 'tls1',
}

account = IMAP {
  server = HOST,
  port = PORT,
  username = USER,
  password = PASS,
  ssl = 'tls1'
}

-- Helper to split SYNC_FOLDERS env string into a table, respecting quotes
local function parse_folders(value)
  local folders = {}
  if not value or value == '' or value == '*' then
    -- Discover all folders
    local ok, list = pcall(function() return account:list_all() end)
    if ok and list then
      for _, f in ipairs(list) do table.insert(folders, f) end
    else
      folders = { 'INBOX' }
    end
  else
    for name in value:gmatch('%b""') do
      table.insert(folders, name:sub(2, -2))
    end
    -- unquoted words
    for name in value:gmatch('%S+') do
      if name:sub(1,1) ~= '"' then table.insert(folders, name) end
    end
    if #folders == 0 then folders = { 'INBOX' } end
  end
  return folders
end

local SYNC_FOLDERS = env('SYNC_FOLDERS') or '*'
local folders = parse_folders(SYNC_FOLDERS)

-- Date cutoff string like 365 days ago
local older_than = string.format('%d', PRUNE_DAYS)

print(string.format('imapfilter: pruning folders=%s, older_than=%s days, dry_run=%s', table.concat(folders, ','), older_than, tostring(DRY_RUN)))

for _, folder in ipairs(folders) do
  local mbox = account[folder]
  if mbox == nil then
    print('Warning: folder not found: ' .. folder)
  else
    local to_delete = mbox:is_older(older_than)
    local count = #to_delete
    if count > 0 then
      if DRY_RUN then
        print(string.format('[DRY RUN] Would delete %d messages from %s', count, folder))
      else
        print(string.format('Deleting %d messages from %s', count, folder))
        mbox:delete_messages(to_delete)
        mbox:expunge()
      end
    else
      print(string.format('No messages older than %s days in %s', older_than, folder))
    end
  end
end


