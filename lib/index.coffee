
path = require 'path'

###

HTTP server (using forever)
===========================

Register two commands, `http start` and `http stop`. It is similar to the http 
plugin but use forever instead of the `start_stop` utility present in shell. Internally, 
the plugin use the Forever module. The start command will 
search for one of "./app.js", "./server.js", "./lib/app.js" and "./lib/server.js" (and 
additionnaly their CoffeeScript alternatives) and execute it.

The following properties may be provided as settings:

-   `workspace`     Project directory used to resolve relative paths and search for "server" and "app" scripts.
-   `cmd`           Command to start the server, not required if path is provided or if the script is discoverable
-   `path`          Path to the js/coffee script starting the process, may be relative to the workspace, extension isn't required.
-   `pidFile`       Path to the file storing the daemon process id. Defaults to `"/.node_shell/#{md5}.pid"`
-   `logFile`       Path to Forever log file.
-   `outFile`       Path to redirect the server stdout.
-   `errFile`       Path to redirect the server stderr.

Example:

```javascript
var shell = require('shell');
var http = require('shell-http-forever');

var app = new shell();
app.configure(function() {
    app.use(http());
    app.use(shell.router({
        shell: app
    }));
});
```

###
module.exports = (settings = {}) ->
    # Load dependency
    forever = require 'forever'
    # Register commands
    cmd = () ->
        # Path is user-provided or auto-discovered
        searchs = if settings.path then [settings.path] else ['app', 'server', 'lib/app', 'lib/server']
        for search in searchs
            # Path is relative to workspace
            search = path.resolve settings.workspace, search
            # If it exists, determin the executable
            if path.existsSync "#{search}"
                if search.substr(-4) is '.coffee'
                then return ['coffee', "#{search}"]
                else return ['node', "#{search}"]
            # Otherwise, try to see if filename is without an extension
            if path.existsSync "#{search}.js"
                return ['node', "#{search}.js"]
            else if path.existsSync "#{search}.coffee"
                return ['coffee', "#{search}.coffee"]
        throw new Error 'Failed to discover a "server.js" or "app.js" file'
    route = (req, res, next) ->
        app = req.shell
        # Caching
        return next() if app.tmp.http_forever
        app.tmp.http_forever = true
        # Workspace settings
        settings.workspace ?= app.set 'workspace'
        throw new Error 'No workspace provided' if not settings.workspace
        # Messages
        # file = './lib/app/index.coffee'
        # options = 
        #     command: 'coffee'
        #     watch: true
        #     watchDirectory: settings.workspace
        #     cwd: settings.workspace
        #     pidFile: "#{settings.workspace}/var/pids/http.pid"
        #     logFile: "#{settings.workspace}/var/logs/http.log"
        #     outFile: './var/logs/http_out.log'
        #     errFile: './var/logs/http_err.log'

        [command, file] = cmd()
        options = 
            command: command
            watch: true
            watchDirectory: settings.workspace
            cwd: settings.workspace
            pidFile: path.resolve settings.workspace, settings.pidFile or './var/pids/http.pid'
            logFile: path.resolve settings.workspace, settings.logFile or './var/logs/http.log'
            outFile: path.resolve settings.workspace, settings.outFile or './var/logs/http_out.log'
            errFile: path.resolve settings.workspace, settings.errFile or './var/logs/http_err.log'
        app.cmd 'http start', 'Start HTTP server', (req, res, next) ->
            monitor = forever.startDaemon file, options
            monitor.on 'start', ->
                forever.startServer monitor
        app.cmd 'http stop', 'Stop HTTP server', (req, res, next) ->
            runner = forever.stop file, true
            runner.on 'stop', (process) ->
                forever.log.info 'Forever stopped process:'
                forever.log.data process
            runner.on 'error', (err) ->
                forever.log.error 'Forever cannot find process with index: ' + file
        next()
    # if arguments.length is 1
    #     settings = arguments[0]
    #     return route
    # else
    #     route.apply null, arguments
