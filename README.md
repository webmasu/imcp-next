<picture>
  <source media="(prefers-color-scheme: dark)" srcset="Assets/hero-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="Assets/hero-light.svg">
  <img src="Assets/hero-light.svg" alt="iMCP">
</picture>

iMCP Next is a fork of [iMCP](https://github.com/mattt/iMCP) that connects its Messages tools to imsg on this Mac or a macOS VM.
It works with [Claude Desktop][claude-app],
the [ChatGPT desktop app][chatgpt-app],
local models served by [llama.cpp][llama-cpp],
and a [growing list of clients][mcp-clients] that support the
[Model Context Protocol (MCP)][mcp].

## Capabilities

<table>
  <tr>
    <th width="48">
      <img src="Assets/calendar.svg" width="48" height="48" alt="" role="presentation"/>
    </th>
    <td><strong>BusyCal</strong></td>
    <td>Read BusyCal calendars, events, tasks and availability. Optionally enable changes through <a href="#busycal">BusyMac’s official MCP bridge</a>.</td>
  </tr>
  <tr>
    <th width="48">
      <img src="Assets/calendar.svg" width="48" height="48" alt="" role="presentation"/>
    </th>
    <td><strong>Calendar</strong></td>
    <td>View and manage calendar events, including creating new events with customizable settings like recurrence, alarms, and availability status.</td>
  </tr>
  <tr>
    <th width="48">
      <img src="Assets/contacts.svg" width="48" height="48" alt="" role="presentation"/>
    </th>
    <td><strong>Contacts</strong></td>
    <td>Search, create and edit Apple contacts. Inspect linked cards by account and delete an individual source card.</td>
  </tr>
  <tr>
    <th width="48">
      <img src="Assets/home.svg" width="48" height="48" alt="" role="presentation"/>
    </th>
    <td><strong>Home</strong></td>
    <td>Find homes, rooms, accessories, scenes, and automations, read and control accessories, and organize rooms and zones. Needs a helper app that you <a href="#imcp-helper">build with your own Apple Developer account</a>.</td>
  </tr>
  <tr>
    <th width="48">
      <img src="Assets/location.svg" width="48" height="48" alt="" role="presentation"/>
    </th>
    <td><strong>Location</strong></td>
    <td>Access current location data and convert between addresses and geographic coordinates.</td>
  </tr>
  <tr>
    <th width="48">
      <img src="Assets/mail.svg" width="48" height="48" alt="" role="presentation"/>
    </th>
    <td><strong>Mail</strong></td>
    <td>List mailboxes, search messages by sender, subject, mailbox, date, or read status, read conversations across mailboxes, mark messages, refresh accounts, and compose, send or schedule mail. Reading mail needs <a href="#mail-access-and-search">access to your Mail folder</a>.</td>
  </tr>
  <tr>
    <th width="48">
      <img src="Assets/maps.svg" width="48" height="48" alt="" role="presentation"/>
    </th>
    <td><strong>Maps</strong></td>
    <td>Search places and address suggestions, calculate distance, request driving, walking or cycling directions and transit estimates with departure, arrival, distance and a route link, and generate map images.</td>
  </tr>
  <tr>
    <th width="48">
      <img src="Assets/messages.svg" width="48" height="48" alt="" role="presentation"/>
    </th>
    <td><strong>Messages</strong></td>
    <td>List conversations, search messages, read history and optionally send texts through local or remote imsg.</td>
  </tr>
  <tr>
    <th width="48">
      <img src="Assets/music.svg" width="48" height="48" alt="" role="presentation"/>
    </th>
    <td><strong>Music</strong></td>
    <td>See what's playing in the Music app, control playback, list your playlists and their tracks, and search the Apple Music catalog. Playback and playlist tools need Automation permission for Music; catalog search needs Apple Music access.</td>
  </tr>
  <tr>
    <th width="48">
      <img src="Assets/notes.svg" width="48" height="48" alt="" role="presentation"/>
    </th>
    <td><strong>Notes</strong></td>
    <td>Search and read notes as Markdown. Open notes in Notes, create them from HTML, and replace the contents of unlocked notes without embedded items.</td>
  </tr>
  <tr>
    <th width="48">
      <img src="Assets/phone.svg" width="48" height="48" alt="" role="presentation"/>
    </th>
    <td><strong>Phone</strong></td>
    <td>View call history synced from your iPhone, filter calls by participant, date, or call type, and start calls with system confirmation.</td>
  </tr>
  <tr>
    <th width="48">
      <img src="Assets/reminders.svg" width="48" height="48" alt="" role="presentation"/>
    </th>
    <td><strong>Reminders</strong></td>
    <td>View, create, edit, and delete reminders with customizable due dates, recurrence, priorities, and alerts across different reminder lists, and manage the lists themselves.</td>
  </tr>
  <tr>
    <th width="48">
      <img src="Assets/shortcuts.svg" width="48" height="48" alt="" role="presentation"/>
    </th>
    <td><strong>Shortcuts</strong></td>
    <td>Browse folders and shortcut details, open shortcuts in the editor, and run them with text or files.</td>
  </tr>
  <tr>
    <th width="48">
      <img src="Assets/voice-memos.svg" width="48" height="48" alt="" role="presentation"/>
    </th>
    <td><strong>Voice Memos</strong></td>
    <td>Fetch recordings from Voice Memos, with transcripts and audio, filtering by title, folder, or date, or reading Recently Deleted. Needs <a href="#voice-memos-library-access">access to your Voice Memos folder</a>.</td>
  </tr>
  <tr>
    <th width="48">
      <img src="Assets/voicemail.svg" width="48" height="48" alt="" role="presentation"/>
    </th>
    <td><strong>Voicemail</strong></td>
    <td>Fetch voicemails synced from your iPhone, with transcripts and audio, filtering by sender, date, message type, or mailbox (inbox, blocked, or deleted).</td>
  </tr>
  <tr>
    <th width="48">
      <img src="Assets/weather.svg" width="48" height="48" alt="" role="presentation"/>
    </th>
    <td><strong>Weather</strong></td>
    <td>Get current conditions, forecasts and historical daily weather from August 1, 2021. Request up to ten days in the time zone at the coordinates.</td>
  </tr>
</table>

## Getting Started

To use iMCP, you need two apps:
iMCP, which gives access to the services you turn on,
and an AI app that can connect to MCP servers.
Install iMCP and turn on services first.
Then follow the instructions for your AI app:

- [Claude Desktop](#connect-to-claude-desktop)
- [ChatGPT desktop app](#connect-to-the-chatgpt-desktop-app)
- [Claude Code, llama.cpp, and other clients](#connect-to-other-clients)

### Build and open iMCP Next

With Xcode and an Apple Development signing identity installed, run these commands in the checkout. Replace `TEAM_ID` with your Apple developer team ID. Xcode uses automatic provisioning for the local build.

```sh
Scripts/build-local-app.sh TEAM_ID
Scripts/install-imsg-connection.sh
open .build/Build/Products/Release/iMCP.app
```

You can copy the built app to `~/Applications/iMCP Next.app`. Use the copy's **Copy server command to clipboard** button when configuring a client. The proxy starts the signed app in the background on first connection. The fork has its own socket, client approvals and settings. For connection options, see [Messages via imsg](#messages-via-imsg).

<img align="right" width="344" src="/Assets/imcp-screenshot-first-launch.png" alt="Screenshot of the iMCP menu, with the Enable MCP Server switch at the top and a list of services below it" />

When you open the app,
you'll see a
<img style="display: inline" width="20" height="16" src="/Assets/icon.svg" />
icon in your menu bar.

Click this icon to open the iMCP menu.
The blue "Enable MCP Server" switch at the top indicates that
the MCP server is running and ready to connect with AI apps.
iMCP must be open for AI apps to use it.

Below the switch, the menu lists the available services.
Maps is on when you first open iMCP;
the other services are off and appear in gray.
iMCP also includes a tool that plays a system sound.
That tool is always available, even with every service off,
so you can test a connection without granting any permissions.

<br clear="all">

<img align="right" width="372" src="/Assets/imcp-screenshot-grant-permission.png" alt="Screenshot of macOS permission dialog" />

### Turn on services

To turn on a service, click its icon.
macOS asks you for permission.
For example, when you turn on Calendar,
a dialog asks "'iMCP' Would Like Full Access to Your Calendar".
Click "Allow Full Access" to continue.

> [!IMPORTANT]
> iMCP **does not** collect or store any of your data.
> AI apps like Claude and ChatGPT _do_ send
> your data off device as part of tool calls.
> Turn on only the services you want your AI app to use.
> To keep your data on your Mac,
> [use a local model with llama.cpp](#llamacpp).

<br clear="all">

<img align="right" width="344" src="/Assets/imcp-screenshot-all-services-active.png" alt="Screenshot of the iMCP menu with all services turned on" />

When a service is on,
its icon changes from gray to the service's color:
red for Calendar, green for Messages, blue for Location, and so on.

Repeat these steps for each service that you want to use.
macOS asks for each permission separately,
so iMCP can access only the data that you allow.
To turn off a service, click its icon again.
To turn off individual tools in a service,
click <img style="display: inline" width="20" height="16" src="/Assets/icon.svg" />
\> "Settings", and then click the service in the sidebar.

<br clear="all">

### Approve connections

<img align="right" width="372" src="/Assets/imcp-screenshot-approve-connection.png" alt="Screenshot of the iMCP Connection Request dialog with Deny and Allow buttons" />

The first time an AI app connects,
iMCP shows a "Client Connection Request" dialog
with the name the app reports
and the services that the app can use.
Click "Allow" to connect.
"Allow" turns on a second after the dialog opens,
and pressing Return doesn't click it,
so that a click or a key press meant for another window
doesn't approve a client as the dialog opens.
If you don't answer within two minutes, iMCP denies the connection.
After you deny a client that presents a credential,
iMCP denies connections with that credential
without asking for 30 seconds.
iMCP shows up to three dialogs at once,
and refuses connections while "Enable MCP Server" is off.

Any app can report any name,
so iMCP doesn't trust a client by its name.
Instead, iMCP trusts a client that presents a credential iMCP created for it.
`imcp-server` reads the credential from the `IMCP_CLIENT_CREDENTIAL`
environment variable in the client's MCP settings,
and sends it to iMCP after it checks that iMCP is genuine.
iMCP stores only a hash of each credential, in your Keychain.

To skip the dialog next time, select "Always trust this client".
If the client already presents a credential,
for example because iMCP [set up Claude Desktop](#connect-to-claude-desktop),
iMCP trusts that credential.
Otherwise, iMCP creates a credential and shows it once.
Click "Copy Value"
and add `IMCP_CLIENT_CREDENTIAL` with that value
to the environment of the iMCP server in the client's MCP settings.
iMCP then shows a notification each time the client connects.
You can remove trusted clients in
<img style="display: inline" width="20" height="16" src="/Assets/icon.svg" />
\> "Settings" > "Clients",
which revokes their credentials and closes their connections.

> [!NOTE]
> Earlier versions of iMCP trusted clients by name.
> Those clients need your approval again;
> select "Always trust this client" to give each one a credential.

<br clear="all">

<details>
<summary>Add a credential to a client's MCP settings</summary>

In a JSON configuration file, add the credential to the server's `env`:

```json
{
  "mcpServers": {
    "iMCP": {
      "command": "/Applications/iMCP.app/Contents/MacOS/imcp-server",
      "env": {
        "IMCP_CLIENT_CREDENTIAL": "{paste the copied value}"
      }
    }
  }
}
```

With Claude Code, add the server again with the `-e` option:

```console
claude mcp remove --scope user iMCP
claude mcp add --scope user -e IMCP_CLIENT_CREDENTIAL={paste the copied value} \
  iMCP -- /Applications/iMCP.app/Contents/MacOS/imcp-server
```

Anyone who can read the client's settings can use the credential,
so keep those files private to your user account.
If you think that a credential was exposed,
remove the client in "Settings" > "Clients" and trust it again.

</details>

### Calendar, reminder lists and shortcuts

`events_create` and `events_update` accept the same `recurrence` object as Reminders.
For the first Monday of each month, use
`{"frequency":"monthly","daysOfTheWeek":["first monday"]}`.
To replace a series rule from a particular occurrence, pass its start time and
`"span":"futureEvents"`. Set `recurrence` to `null` to stop repeating.
Reminder list creation and renaming accept `color` in `#RRGGBB` format.

`shortcuts_list` accepts `folder` and `details`. Use `shortcuts_folders` to discover folders and
`shortcuts_open` to open a shortcut in the editor. In Settings → Shortcuts, choose a folder
for `shortcuts_run` file inputs and outputs. Supply absolute paths in `inputPath` and
`outputPath`. The output path must be new. Text input and output remain available.

### Mail access and search

Use `mail_send` for immediate delivery or `mail_schedule` with an ISO 8601
`scheduledTime` that includes a UTC offset. Each accepts a configured sender address,
recipient arrays, a subject and a plain-text body. Mail and Notes actions and
detailed shortcut metadata can prompt for macOS Automation permission.

The schedule is stored locally. iMCP checks due messages while running with the
server, Mail service, `mail_send` and `mail_schedule` enabled. It picks up overdue
messages after launch or wake. Use `mail_mark` with `id` or `ids` to change read status.
Filter the queue with `mail_scheduled_list(status:)`. Cancel pending entries by
`id`, `ids`, or explicit `status: "pending"` with `mail_scheduled_cancel`.
Use `mail_scheduled_delete` with an ID, IDs or a finished status to clear history. An accepted entry means Mail
accepted the send request. If the result is unconfirmed, check Mail before resending.

Mail store access uses [Envelope](https://github.com/mattt/Envelope),
which reads the local index and message files
and selects readable content with its internal MIME reader.
iMCP manages folder access, tool arguments, JSON output, and composition.

Mail reading requires access to `~/Library/Mail`.
If folder access is unavailable, `mail_compose` can still open a compose window
in the default email app.
It does not save or send a message.

Mail reads use a read-only SQLite connection and require WAL journal mode.
iMCP does not change the index's journal mode or run checkpoints.
Envelope serializes its database operations. For Envelope reads,
concurrent reads wait their turn,
and a read returns an error if SQLite reports a lock conflict.
Each Envelope SQL statement has a 100 ms execution budget,
all statements of one read share a 1 s budget,
and statements check task cancellation.
The deadline is cooperative; it cannot interrupt a filesystem operation
while SQLite is waiting for that operation to finish.
Slow searches can fail instead of returning results.
Service status checks do not open SQLite connections,
and message reads close the database before scanning mailbox files.
These limits reduce interference, but active reads can still delay WAL checkpoints.

Use the `@id` string from `mail_mailboxes_list` as the `mailbox` filter
in `mail_messages_search`, for example `{"mailbox": "V10:12"}`.
The identifier includes the Mail store,
so an identifier from before a Mail store upgrade returns an error.
The `url` field describes storage and is not a search identifier.
Each mailbox includes an account identifier when available.
The account's `email` field comes from Mail's local account map;
it is `null` when that map is missing or does not contain an email address.

Search results include `localIndex.indexedMessageCount` for the selected mailbox,
or all mailboxes when no mailbox is selected, before filters and pagination.
This count includes label membership without counting a message twice.
Sync status is reported as `unknown`.
A count of zero can mean an empty mailbox or missing local indexing;
it cannot show whether Mail has ever indexed the account.
Open Mail to check account sync.

Search results are newest first.
When more messages match, the result includes a `nextCursor` value;
pass it as `cursor` with the same filters to get the next page.
A cursor names the last message of a page,
so mail that arrives between requests does not shift later pages.

Search matches sender and subject metadata only.
`mail_messages_read` can read the local content of a returned message.
It lists attachments without their content.
When Mail stores a message's attachments or inline images in separate files,
the message file keeps the text, and each of those attachments has
`isStoredSeparately` set to `true`.
Body search is not available, and these tools do not download messages.

### Connect to Claude Desktop

If you don't have Claude Desktop installed,
you can [download it here](https://claude.ai/download).

Open Claude Desktop and choose Claude > "Settings" (<kbd>⌘</kbd><kbd>,</kbd>).
Click "Developer" in the sidebar,
and then click "Edit Config".
This creates a configuration file at
`~/Library/Application Support/Claude/claude_desktop_config.json`.

<br/>

To connect iMCP to Claude Desktop,
click <img style="display: inline" width="20" height="16" src="/Assets/icon.svg" />
\> "Configure Claude Desktop",
and then click "Set Up".

iMCP adds or updates its entry in the configuration file
so that Claude Desktop starts the `imcp-server` executable in the app,
with a credential that identifies Claude Desktop to iMCP.
iMCP keeps the other MCP servers in the file.
The first time Claude Desktop connects, iMCP still asks you to approve it;
select "Always trust this client" to trust its credential.

<details>
<summary>Configure Claude Desktop manually</summary>

Click <img style="display: inline" width="20" height="16" src="/Assets/icon.svg" />
\> "Copy server command to clipboard".
Then open `claude_desktop_config.json` in your editor
and enter the following:

```json
{
  "mcpServers": {
    "iMCP": {
      "command": "{paste iMCP server command}"
    }
  }
}
```

</details>

### Call iMCP tools from Claude Desktop

Quit and reopen the Claude Desktop app.
iMCP asks you to [approve the connection](#approve-connections).

After you approve the connection,
a 🔨 icon with the number of available tools
appears in the lower-right corner of the chat box.
Click it to see the iMCP tools that Claude can use.

<p align="center">
  <img width="694" src="/Assets/claude-desktop-screenshot-tools-enabled.png" alt="Screenshot of Claude Desktop with tools enabled" />
</p>

Now you can ask Claude questions that require access to your personal data,
such as:

> "How's the weather where I am?"

Claude uses iMCP tools to get this information,
so you don't have to share it in the conversation yourself.

<p align="center">
  <img width="738" src="/Assets/claude-desktop-screenshot-message.png" alt="Screenshot of Claude response to user message 'How's the weather where I am?'" />
</p>

### Connect to the ChatGPT desktop app

If you don't have the ChatGPT desktop app installed,
you can [download it here][chatgpt-app].

> [!NOTE]
> These steps use the labels in ChatGPT 26.930 for macOS
> and haven't been tested end to end yet.
> OpenAI documents MCP servers for
> [Codex mode](https://learn.chatgpt.com/docs/extend/mcp),
> so use iMCP in a Codex conversation.

1. Click <img style="display: inline" width="20" height="16" src="/Assets/icon.svg" />
   \> "Copy server command to clipboard".
2. In ChatGPT, open Settings (<kbd>⌘</kbd><kbd>,</kbd>)
   and click "MCP servers" in the sidebar.
3. Click "Add server".
   Enter `iMCP` for "Name", choose "STDIO" for "Type",
   and paste the copied command into "Command to launch".
   Leave the other fields empty.
4. Click "Save", and then click "Restart".
5. [Approve the connection](#approve-connections) in iMCP.
   ChatGPT might identify itself as `codex-mcp-client`.

To test the connection,
start a new Codex conversation and send this message:

> "Use iMCP to play a system sound."

Your Mac plays a short sound.
If your Mac is muted, open the tool call in the conversation;
a result of `true` means that iMCP received the request.

<details>
<summary>Troubleshooting the ChatGPT desktop app</summary>

- **Settings doesn't show "MCP servers".**
  Update ChatGPT and switch to Codex mode.
  If ChatGPT shows "MCP server settings are unavailable"
  and an organization manages your account,
  ask your administrator whether you can add MCP servers.
- **iMCP doesn't show an approval dialog.**
  ChatGPT can't open iMCP for you.
  Make sure that iMCP is open and "Enable MCP Server" is on,
  and then click "Restart" in ChatGPT's "MCP servers" settings.
  The dialog can also open behind other windows.
  If you added a trusted credential to ChatGPT's settings,
  iMCP shows a notification instead of a dialog.
- **ChatGPT can't use iMCP tools.**
  Make sure that you're in a Codex conversation
  and that iMCP is turned on in ChatGPT's "MCP servers" settings.
  If you clicked "Deny", click "Restart" to see the dialog again.
  If ChatGPT presents a credential, wait 30 seconds first.
  If you turned on a service after connecting, click "Restart"
  so that ChatGPT loads its tools.
- **A service doesn't turn on in iMCP.**
  If you denied permission when macOS asked,
  open System Settings > "Privacy & Security",
  click the category for the service, such as "Calendars",
  and turn on iMCP.
  Then click the service icon in the iMCP menu again.
- **ChatGPT shows an error for the iMCP server.**
  The command might point to the wrong place,
  for example, if you moved iMCP after setting it up.
  Copy the server command again,
  open the iMCP server's settings in ChatGPT,
  and replace "Command to launch" with the copied command.
  Make sure that "Arguments" is empty,
  and then click "Save" and "Restart".

</details>

### Connect to other clients

Most MCP clients can start iMCP as a local server
that uses the STDIO transport.
Click <img style="display: inline" width="20" height="16" src="/Assets/icon.svg" />
\> "Copy server command to clipboard",
and then enter the copied command
as the command for a new STDIO server in your client.
The copied command is the full path to the `imcp-server` executable
in your copy of iMCP.

The commands below assume that iMCP is in your Applications folder.
If you installed iMCP somewhere else,
replace `/Applications/iMCP.app/Contents/MacOS/imcp-server`
with the copied command.

#### [Claude Code][claude-code]

To add iMCP for all of your projects, run this command:

```console
claude mcp add --scope user iMCP -- /Applications/iMCP.app/Contents/MacOS/imcp-server
```

<details>
<summary>Or import from Claude Desktop</summary>

If you've already configured Claude Desktop, you can import its MCP servers:

```console
claude mcp add-from-claude-desktop
```

</details>

#### [llama.cpp][llama-cpp]

You can use iMCP with an open model that runs on your Mac
through [llama.cpp][llama-cpp],
so your conversations and tool results stay on your Mac.
`llama-server` (or `llama serve`) starts the MCP servers
listed in a configuration file
and gives their tools to models in its web UI.
This requires llama.cpp 0.1.0 or later.

Create a file at `~/.config/llama/mcp.json` with the following contents:

```json
{
  "mcpServers": {
    "imcp": {
      "command": "/Applications/iMCP.app/Contents/MacOS/imcp-server"
    }
  }
}
```

Then start the server with the `--mcp-servers-config` option
and a model that supports tool calling:

```console
llama serve --mcp-servers-config ~/.config/llama/mcp.json \
            -hf ggml-org/Qwen3-4B-GGUF
```

Open the web UI at <http://localhost:9931>
(llama.cpp versions before 0.7.0 use port 8080).
iMCP tools appear with an `imcp_` prefix,
such as `imcp_weather_current`.
The web UI asks you before it runs each tool call,
unless you choose to always allow that tool.

<details>
<summary>Use the Llama app</summary>

[Llama][llama-app] is a menu bar app that runs `llama serve` for you.
It doesn't have a setting for MCP servers,
so add the `--mcp-servers-config` option to its custom server arguments:

```console
defaults write app.llama.Llama extraServerArgs -string "--mcp-servers-config $HOME/.config/llama/mcp.json"
```

Llama splits this value at each space and doesn't expand `~`,
so use the full path to the file, without spaces.
If you already set custom server arguments,
add the option to your existing value.
Quit and reopen Llama,
then open the web UI at <http://localhost:9931>.

</details>

> [!IMPORTANT]
> When the server starts,
> it waits 10 seconds for iMCP to list its tools.
> If you don't [approve the connection](#approve-connections)
> from "llama.cpp" in that time,
> no iMCP tools appear until you restart the server.

## Technical Details

### App & CLI

iMCP is a macOS app that bundles a command-line executable, `imcp-server`.

- [`iMCP.app`](/App/) provides UI for configuring services and — most importantly —
  a means of interacting with macOS system permissions,
  so that it can access Contacts, Calendar, and other information.
- [`imcp-server`](/CLI/) provides an MCP server that
  uses standard input/output for communication
  ([stdio transport][mcp-transports]).

The app and CLI communicate over a Unix domain socket
in the app's sandbox container, at
`~/Library/Containers/io.webmasu.iMCP/Data/Library/Caches/mcp.sock`.
The CLI derives that path from the app's bundle identifier,
so it needs no network access or service discovery.
Before either side sends anything,
it reads the other's audit token from the socket
and checks the other's code signature.
The CLI accepts only an app signed by its own Apple team
with the identifier `io.webmasu.iMCP`,
and the app accepts only a CLI signed by the same team
with the identifier `imcp-server`.
Requests from MCP clients are read by the CLI from `stdin`
and relayed to the app;
responses from the app are received by the CLI and written to `stdout`.
See [`LocalSocket`](/CLI/LocalSocket.swift)
and [`StdioProxy`](/CLI/StdioProxy.swift)
for implementation details.

Debug builds made with `CODE_SIGNING_ALLOWED=NO` are signed ad hoc,
so they have no team to check and no App Sandbox entitlement.
In Debug builds only,
each side also accepts a peer that has the expected identifier
(`imcp-server`, or `iMCP` or `io.webmasu.iMCP` for the app),
and an unsandboxed app listens at
`~/Library/Caches/io.webmasu.iMCP/mcp.sock`,
which the Debug CLI tries after the container path.
Any process can claim an identifier,
so don't use Debug builds with your own data.
Release builds don't contain this code.

For this project, we created what became
[the official Swift SDK][swift-sdk]
for Model Context Protocol servers and clients.
The app uses this package to handle proxied requests from MCP clients.

### Messages via imsg

In **Settings > Messages**, select a connection, click **Test Connection**, then enable Messages. The test calls `status` and shows the imsg version and database and bridge readiness. Sign in to Messages on the selected Mac. For remote connections, start the guest before testing.

| Connection | Host configuration |
| --- | --- |
| imsg-vm (default) | Uses the host's `~/.local/bin/imsg-vm` launcher to find the guest and connect over SSH. Reads use `imsg-vm imsg-ro` and changes use `imsg-vm imsg`. Attachment export uses the same VM's SSH connection. |
| imsg | Enter the absolute path to an imsg executable installed on this Mac. An empty field checks `/opt/homebrew/bin/imsg`, then `/usr/local/bin/imsg`. The executable runs `rpc` against this Mac's Messages database. Use imsg 0.21.1 for the full tool set documented below. |
| SSH host | Enter a `Host` alias from the host Mac's `~/.ssh/config`. Configure its user, identity and known host key. iMCP uses noninteractive SSH and runs `/usr/local/bin/imsg rpc` in the guest. Test SSH access with `ssh -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes YOUR_ALIAS /usr/local/bin/imsg --version`. |

`Scripts/install-imsg-connection.sh` installs the host helper and operation catalog in `~/Library/Application Scripts/io.webmasu.iMCP/`. The sandboxed app starts it on demand using `NSUserUnixTask`. It needs Python 3.8 or later at `/usr/bin/python3` on the host. There is no listener to start in the guest. Run the installer again after updating the script.

| MCP tool | imsg RPC | Use |
| --- | --- | --- |
| `messages_chats` | `chats.list` | Find a numeric chat ID. Optionally list only unread conversations. |
| `messages_history` | `messages.history` | Read one chat. Optional filters cover participants and dates. Set `attachments` to include metadata and paths on the selected Mac. |
| `messages_search` | `messages.search` | Search across conversations by text. |
| `messages_send` | `send` | Send text, a file or both to one recipient or existing chat. Enable **Send Text and Attachments** under Messages. |

Use `messages_capabilities` to check the connected imsg version and its currently usable RPC methods. The operation catalog covers imsg 0.21.1 including accounts, groups, scheduled messages, statistics, read receipts, typing, polls, reactions, edits, stickers, multipart sends, contact sharing and group membership. Each tool with a native RPC equivalent also accepts its exact `native_params` object in place of the CLI fields. Use `messages_after` for resumable catch-up and `messages_watch` or `messages_events` for a bounded 1–30 second observation. Bridge availability depends on the selected Mac. Installation and bridge administration are local operations.

The **Allow Advanced Sends and Changes in Messages** setting enables the additional mutating tools. Individual tools can then be turned off. A lost connection can follow a committed change. Read back the message or chat before retrying.

To retrieve an image or document, call `messages_history` with `attachments: true`, then pass its `original_path` to `messages_attachment`. The tool copies a downloaded regular file up to 64 MiB into a private temporary folder on the host and returns its path. Remote export requires /usr/bin/python3 on the Messages Mac. Sending with imsg-vm accepts a host path through the wrapper's shared-folder staging. Plain SSH sends use paths on the remote Mac.

### BusyCal

Run `Scripts/install-busycal.sh` on the Mac that runs BusyCal, then enable **BusyCal**
in iMCP Next settings. The installer downloads BusyMac’s official MCP bundle 1.3.0,
verifies the release checksum and developer signature, and installs it locally. It
requires BusyCal 2026.4.7 beta or later for sub-tasks, bulk reads and overlap searches. For an offline install, pass the downloaded
`.mcpb` file as the script’s only argument.

The existing iMCP connection advertises the vendor’s tools with a `busycal_`
prefix. Start with `busycal_list_calendars`. Calendar and task searches,
availability, and selected items are available by default. Turn on **Allow Changes
in BusyCal** to expose creation, updates, moves and deletion. Individual tools
can also be switched off. Clients with a tool allowlist need the corresponding
prefixed names. BusyCal remains responsible for calendar permissions and syncing.
[BusyMac’s MCP guide](https://www.busymac.com/docs/busycal/70624-mcp/) · [Vendor release and license](https://github.com/BeehiveInnovations/busycal-mcpb)

### Contacts Journal CRM

Run `Scripts/install-contactsjournal.sh`, then enable **Contacts Journal CRM** in settings. Use `contactsjournal_contacts` to find a local CRM contact ID by name or company. Pass it to `contactsjournal_logs` or `contactsjournal_todos`. Both include entries shared with multiple contacts. Use `open_only: true` for pending follow-ups. Approve macOS access to Contacts Journal app data when prompted. Follow `nextOffset` to read another page. These tools open the local Contacts Journal CRM 7.2.1 SQLite store in read-only mode and include committed changes in its WAL.

### BusyContacts

Run `Scripts/install-busycontacts.sh` on the host Mac, then turn on **Settings > BusyContacts** in iMCP Next. Approve macOS access to BusyContacts app data when prompted. The **Create Contacts** and **Update Contacts** switches are independent and both default to off.

| Tool | Use |
| --- | --- |
| `busycontacts_list` | Search names, emails, phones, organizations, job titles, postal addresses, URLs, tags, notes and other stored field values. Limit the search with `field`, or combine the exact `tag` and `addressBook` filters. Omit the query to list everyone. Pass `nextAfter` as `after` with the same query to read the next page. |
| `busycontacts_tags` | List assigned tags and their contact counts, optionally in an address book. |
| `busycontacts_get` | Read a person by numeric BusyContacts `id`. Returns a vCard, `hasPhoto`, a revision and the original BusyContacts field list in `busyContactsFields`, including custom labels and provider values. Set `includePhoto` to `false` to omit the image from the response. |
| `busycontacts_photo` | Read the contact photo as an MCP image. Uses the BusyContacts cached original when available, with the macOS account photo as a fallback. |
| `busycontacts_create` | Supply `details` and an optional `addressBook` for Quick Entry, or supply a complete `vcard`. For a vCard, BusyContacts opens its import dialog so you can choose the address book and confirm. A submitted request can be checked with `busycontacts_list`. |
| `busycontacts_update` | Supply `id`, the `revision` from `busycontacts_get`, and the desired changes. The tool saves through the macOS Contacts framework to the exact account card. |

To edit a phone number, read the card, edit its `TEL` entry and pass the edited vCard with `fields: ["phoneNumbers"]`. Include every phone number you want to keep. To replace only the photo, send `photoBase64` with the ID and revision. To remove it, send `removePhoto: true`. Images can be up to 5 MiB and 40 megapixels. Exports use vCard 3.0 with an embedded photo. BusyContacts notes are exported as plain text. Existing notes, tags and provider-specific vCard properties are read-only in the update tool. macOS requires a separately approved entitlement to edit existing contact notes. [Apple’s contact notes entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.contacts.notes)

Full cards, photos and edits require Contacts access for iMCP Next and an address book that both apps sync through the same account. The helper matches the account collection, card UID and resource name. It opens the BusyContacts and macOS SQLite stores read-only and checks the cached server revisions before saving. A changed revision or pending sync stops the edit. Read the card again after sync and review the intended fields. Groups and local-only BusyContacts books remain available through the list tool. These readers were checked with BusyContacts 2026.4.4 and depend on the local database schemas.

A `savedLocally` result confirms that macOS accepted the edit. iCloud or Google then syncs it to BusyContacts. Another device can still edit the same field before that sync completes. [BusyMac’s guide to syncing with Apple Contacts](https://www.busymac.com/docs/busycontacts/49374-syncing-with-apple-contacts/) · [Apple’s save semantics](https://developer.apple.com/documentation/contacts/cnsaverequest)

### Call History Database Access

Call history synced from your iPhone lives in a SQLite database at
`~/Library/Application Support/CallHistoryDB/CallHistory.storedata`.
Recent calls sit in its write-ahead log next to the store file,
so the Phone service asks you to open the `CallHistoryDB` folder
rather than the file alone.

### Visual Voicemail Database Access

Voicemails synced from your iPhone by the Phone app (on macOS 26 and later)
live in a SQLite database at
`~/Library/Group Containers/group.com.apple.FaceTime/com.apple.facetimemessagestored/Data Store/FaceTimeMessageStore-local.sqlitedb`.
The store is a write-ahead log database, and the message audio sits in an `Assets`
tree beside it, so the Voicemail service asks you to open the `Data Store` folder
rather than the file alone.

### Voice Memos Library Access

Voice Memos keeps its library in a SQLite database at
`~/Library/Group Containers/group.com.apple.VoiceMemos.shared/Recordings/CloudRecordings.db`.
The audio files sit beside the database,
so the Voice Memos service asks you to open the `Recordings` folder
rather than the file alone.
Voice Memos writes each transcript into the audio file of its recording,
so a recording has a transcript only when its audio is on your Mac.

For this project, we created [TSRP][tsrp]:
a Swift package for reading your Voice Memos library.
It reads transcripts from both `.m4a` and `.qta` files,
which keep them in different places.

### Notes Database Access

Apple doesn't provide public APIs for accessing your notes, either.
The Notes app keeps them in a SQLite database at
`~/Library/Group Containers/group.com.apple.notes/NoteStore.sqlite`.
Recent edits sit in its write-ahead log,
so the Notes service asks you to open the `group.com.apple.notes` folder
rather than the file alone.
iMCP only reads the database; it never changes your notes.

Each note's contents are stored as a gzip-compressed protocol buffer:
the text, followed by runs that give the formatting of each part of it.
Tables are stored separately, as the state of a CRDT
that lists the rows, the columns, and the cell at each intersection.
Notes locked with a password are encrypted,
so iMCP can find them by title but can't read their contents.

For this project, we created [TopoText][topotext]:
a Swift package for reading the Notes database,
named after Apple's internal name for the note text format.
It builds on the reverse engineering in Jon Baumann's
[apple_cloud_notes_parser][apple-cloud-notes-parser]
and Steve Dunham's [notesutils][notesutils].
The Notes service reads notes with TopoText and returns them as Markdown.

### JSON-LD for Tool Results

The tools provided by iMCP return results as
[JSON-LD][json-ld] documents.
For example,
the `fetchContacts` tool uses the [Contacts framework][contacts-framework],
which represents people and organizations with the [`CNContact`][cncontact] type.
Here's how an object of that type is encoded as JSON-LD:

```json
{
  "@context": "https://schema.org",
  "@type": "Person",
  "name": "Mattt",
  "url": "https://mat.tt"
}
```

A tool that returns a list, such as `contacts_search`,
returns a JSON-LD document that holds the list in `@graph`
under a single `@context`.
To keep results short,
values nested in another value, including the values in a graph,
leave out `@type`.

[Schema.org][schema.org] provides standard vocabularies for
people, postal addresses, events, and many other objects we want to represent.
And JSON-LD is a convenient encoding format for
humans, AI, and conventional software alike.

For this project, we created [Ontology][ontology]:
a Swift package for working with structured data.
It includes convenience initializers for types from Apple frameworks,
such as those returned by iMCP tools.

### iMCP Helper

Apple doesn't make the HomeKit framework available to native macOS apps,
only to Mac Catalyst apps.
So the Home service runs in a separate Catalyst app,
[`iMCP Helper`](/Helper/).
Apple doesn't allow HomeKit in Developer ID apps,
so iMCP's release build doesn't include the helper.
Build and install it with your own Apple Developer account:

```console
git clone https://github.com/webmasu/imcp-next.git
cd imcp-next
Scripts/install-helper.sh
```

The script signs the helper with your team's development certificate
and installs it in `/Applications`.
Run it with `--help` to choose another team, bundle ID, or install directory.
Xcode must be signed in to your account (Xcode > Settings > Accounts),
and the helper runs only on Macs registered to your team.
Whether free personal teams can use HomeKit isn't verified.
To reschedule a time-based automation in place, use `automations_update`. For an ordinary timer, pass a future whole-minute ISO timestamp as `fire_at`. For a single calendar event, use its local `time` as HH:mm. Update `recurrence` separately. Regular timers accept daily or once, and calendar triggers accept daily or an array of weekdays (1 is Sunday). Scenes, conditions and unrelated triggers retain their existing settings.

Then turn on Home in iMCP Next. From Codex, call `homes_list` to check the connection. When it returns several homes, pass a returned home ID to `rooms_list` or `accessories_list`.
iMCP finds the helper in `/Applications`.
If you installed it somewhere else,
iMCP asks you to choose it when you turn on Home,
or you can choose it in Settings > Home.
When you enable Home,
iMCP launches the helper if it isn't running,
and the helper asks for HomeKit access.
The first time, the helper's window shows an eight-character pairing code,
such as `7KQ2-M9XD`, and numbered steps:
click Copy Code,
click Open iMCP… to open iMCP's Pair with iMCP Helper window,
then paste the code and click Pair.
The button opens the URL `imcp-next://pair`, which carries no data;
iMCP only opens its pairing window for it.
The helper opens that URL only with the app that has iMCP's bundle ID, `io.webmasu.iMCP`,
preferring the running copy, and not with a copy that doesn't declare the `imcp-next` scheme;
otherwise, for example if you built iMCP with another bundle ID,
the helper tells you to choose Pair… in Settings > Home instead.
If the helper's window is behind other windows,
click Open iMCP Helper… in iMCP's window.
The code works once:
when you pair, iMCP sends the helper a new random key,
and both apps keep that key in their keychains.
After five wrong codes, the helper shows a new one.
To pair again, click Pair Again… in the helper's window and confirm;
the helper ends iMCP's connection and shows a new code and the same steps.
The helper keeps running after iMCP quits;
choose Quit iMCP Helper from its app menu, or press Command-Q, to stop it.
The window also reports startup and permission errors.
The Mac's iCloud account must have access to the home,
and writes can require the owner or administrator role.

When updating the fork from source,
rebuild the helper from the tag that matches the new version:

```console
git fetch --tags
git checkout <version>
Scripts/install-helper.sh
```

A helper from an older version may not match the app's Home tools.

The helper's development certificate and provisioning profile expire.
Each is usually valid for one year,
but the certificate can expire first.
To read the profile's expiration date, run:

```console
security cms -D -i "/Applications/iMCP Helper.app/Contents/embedded.provisionprofile" |
  plutil -extract ExpirationDate raw -o - -
```

To read the certificate's expiration date, run:

```console
codesign -d --extract-certificates=/tmp/imcp-helper-cert "/Applications/iMCP Helper.app"
openssl x509 -inform DER -in /tmp/imcp-helper-cert0 -noout -enddate
```

After the earlier of the two dates, the helper may stop launching.
Run `Scripts/install-helper.sh` again to renew it;
the script lets Xcode create a new certificate and profile
when the old ones have expired.

On the first run, provisioning can fail with "PLA Update available".
The team's Account Holder must accept the latest Program License Agreement
in the Apple Developer account.
If you can't write to `/Applications` (for example, as a non-admin user),
the install can fail with a permission error.
Run the script with `--destination ~/Applications` instead.
iMCP then asks you to choose the helper.

Both apps compile the same tool definitions from
[`Shared/Home/HomeTools.swift`](/Shared/Home/HomeTools.swift).
The helper implements them with HomeKit;
the app forwards each call over an MCP connection on the loopback interface,
so the usual service and per-tool switches apply.
Object IDs are HomeKit UUID strings.
Inventory tools return live characteristic values only when `include_values` is true,
with a five-second timeout and at most four outstanding HomeKit reads.
After a lost connection, read-only calls retry once.
Writes are not repeated, because HomeKit may have applied them already;
the error asks the caller to inspect the home before retrying.
HomeKit sometimes refuses characteristic reads, accessory identification,
and scene action edits with "Missing entitlement for API" or "Request not handled".
In some tests, these refusals happened only while the helper was hidden,
or its window was minimized or closed,
but other tests didn't reproduce them, so the cause isn't confirmed.
The error keeps HomeKit's description, domain, and code,
and suggests showing iMCP Helper's window and retrying;
the window can stay behind other windows.

The helper advertises "\_imcp-helper.\_tcp" on the local-only DNS-SD interface,
and iMCP finds it there, whether or not iMCP launched it.
If more than one helper is running,
iMCP tries the one at the chosen location first, then the others.
Connections use TLS with the key from pairing as a pre-shared key,
so a connection without the key fails the TLS handshake.
The cipher suite adds an ECDHE key exchange,
so a recorded connection stays secret even if the key or code is found later.
The pairing connection uses a key derived from the code with PBKDF2,
which makes each guess slow for a process
that advertises itself as the helper while you pair.
If you built the helper with an earlier version of iMCP,
quit it and rebuild it with `Scripts/install-helper.sh`;
iMCP refuses a helper that doesn't declare the current protocol version.
With Home turned on in iMCP,
`uv run Scripts/check-home.py <path-to-imcp-server>` runs a read-only
integration check through iMCP.

#### Building the helper

Building the `iMCP` scheme runs
[`Scripts/build-helper.sh`](/Scripts/build-helper.sh),
which builds the `iMCP Helper` scheme for Mac Catalyst in its own
derived-data directory and copies the product into the app.
A direct target dependency selects the iOS variant of the helper,
so the nested build is required.
Release builds set `EMBED_HOME_HELPER = NO` and leave the helper out.

The HomeKit entitlement requires a development certificate and a
provisioning profile with the HomeKit capability.
So the helper uses automatic signing with team `TTY35UM57S`
in both Debug and Release, even though the native Debug app is unsigned.
To build with another team, change it in the helper target's
Signing & Capabilities tab.
The first Mac Catalyst build for a new bundle ID can fail with
"Entitlement com.apple.developer.homekit not found and could not be included in profile",
because automatic provisioning registers the capability only for the iOS destination.
`Scripts/install-helper.sh` handles this by building for iOS once and retrying.
To do it by hand, build the helper once for iOS to register it,
then build for Mac Catalyst:

```console
xcodebuild -scheme "iMCP Helper" -destination "generic/platform=iOS" \
  -allowProvisioningUpdates build
xcodebuild -scheme "iMCP Helper" -destination "platform=macOS,variant=Mac Catalyst" \
  -allowProvisioningUpdates build
```

CI builds both apps unsigned,
which checks compilation and packaging but can't access HomeKit:

```console
xcodebuild -scheme iMCP -configuration Debug -destination "platform=macOS" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  HELPER_CODE_SIGNING_ALLOWED=NO build
```

## Debugging

### Connecting `imcp-server` to the app

`imcp-server` writes its log to `stderr`,
which most MCP clients save with their own logs.
If it reports that it couldn't connect to iMCP,
make sure that iMCP is open and that its server is turned on;
`imcp-server` keeps trying until the app is available.
Once it relays anything from the MCP client, it doesn't reconnect:
if the connection ends, it exits,
and the client must start it again for a new session,
which iMCP approves again.
If it reports that the process listening at the socket path
isn't a signed copy of iMCP,
something other than iMCP created the socket.
Quit and reopen iMCP, which replaces a socket that it can't verify.

### Using the MCP Inspector

To debug interactions between iMCP and clients,
you can use the [inspector tool](https://github.com/modelcontextprotocol/inspector)
(requires Node.js):

1. Click <img style="display: inline" width="20" height="16" src="/Assets/icon.svg" /> > "Copy server command to clipboard"
2. Open a terminal and run the following commands:

   ```console
   # Download and run inspector package on imcp-server
   npx @modelcontextprotocol/inspector [paste-copied-command]

   # Open inspector web app running locally
   open http://127.0.0.1:6274
   ```

Inspector lets you see all requests and responses between the client and the iMCP server,
which is helpful for understanding how the protocol works.

### Using Companion

<img align="right" width="284" src="/Assets/companion-screenshot-add-server.png" />

[Companion][companion] is a utility for testing and debugging your MCP servers
(requires macOS 15 or later).
It gives you an easy way to browse and interact with
a server's prompts, resources, and tools.
Here's how to connect it to iMCP:

1. Click <img style="display: inline" width="20" height="16" src="/Assets/icon.svg" /> > "Copy server command to clipboard"
2. [Download][companion-download] and open the Companion app
3. Click the <kbd>+</kbd> button in the toolbar to add an MCP server
4. Fill out the form:
   - Enter "iMCP" as the name
   - Select "STDIO" as the transport
   - Paste the copied iMCP server command
   - Click "Add Server"

<br clear="all">

## Acknowledgments

- [Justin Spahr-Summers](https://jspahrsummers.com/)
  ([@jspahrsummers](https://github.com/jspahrsummers)),
  David Soria Parra
  ([@dsp-ant](https://github.com/dsp-ant)), and
  Ashwin Bhat
  ([@ashwin-ant](https://github.com/ashwin-ant))
  for their work on MCP.
- [Christopher Sardegna](https://chrissardegna.com)
  ([@ReagentX](https://github.com/ReagentX))
  for reverse-engineering the `typedstream` format
  used by the Messages app.

## License

This project is available under the MIT license.
See the LICENSE file for more info.

## Legal

iMessage® is a registered trademark of Apple Inc.
This project is not affiliated with, endorsed, or sponsored by Apple Inc.

[app-sandbox]: https://developer.apple.com/documentation/security/app-sandbox
[apple-cloud-notes-parser]: https://github.com/threeplanetssoftware/apple_cloud_notes_parser
[chatgpt-app]: https://chatgpt.com/download
[claude-app]: https://claude.ai/download
[claude-code]: https://claude.com/product/claude-code
[companion]: https://github.com/mattt/Companion
[companion-download]: https://github.com/mattt/Companion/releases/latest/download/Companion.zip
[contacts-framework]: https://developer.apple.com/documentation/contacts
[cncontact]: https://developer.apple.com/documentation/contacts/cncontact
[imessage-exporter]: https://github.com/ReagentX/imessage-exporter
[json-ld]: https://json-ld.org
[llama-app]: https://llama.app
[llama-cpp]: https://github.com/ggml-org/llama.cpp
[madrid]: https://github.com/mattt/Madrid
[mcp]: https://modelcontextprotocol.io/introduction
[mcp-clients]: https://modelcontextprotocol.io/clients
[mcp-transports]: https://modelcontextprotocol.io/docs/concepts/architecture#transport-layer
[notesutils]: https://github.com/dunhamsteve/notesutils
[nsopenpanel]: https://developer.apple.com/documentation/appkit/nsopenpanel
[ontology]: https://github.com/mattt/Ontology
[schema.org]: https://schema.org
[swift-sdk]: https://github.com/modelcontextprotocol/swift-sdk
[topotext]: https://github.com/mattt/TopoText
[tsrp]: https://github.com/mattt/TSRP
[typedstream-blog-post]: https://chrissardegna.com/blog/reverse-engineering-apples-typedstream-format/
