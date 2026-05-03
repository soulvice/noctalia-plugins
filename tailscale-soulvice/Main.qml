
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
  id: root

  property var pluginApi: null

  // Core state
  property bool connect: false
  property bool loading: true
  property string backendState: "Unknown" // Running, Stopped, NeedsLogin, etc.
  property string lastError: ""

  // Self node info
  property string selfHostname: ""
  property string selfIP: ""
  property string selfID: ""
  property bool selfOnline: false

  // Devices on the tailnet
  property var devices: ([])
  property var exitNodes: ([])

  // Current settings
  property string currentExitNode: ""
  property string currentExitNodeName: ""
  property bool exitNodeAllowLANAccess: false
  property bool shieldsUp: false
  property bool acceptRoutes: false
  property bool acceptDNS: true
  property bool advertisingExitNode: false

  // Operation states
  property bool togglingTailscale: false
  property bool settingExitNode: false
  property string settingExitNodeTo: ""
  property bool refreshing: false

  // Persistent cache
  property string cacheFile: Settings.cacheDir + "tailscale.json"

  FileView {
    id: cacheFileView
    path: root.cacheFile
    printErrors: false

    JsonAdapter {
      id: cacheAdapter
      property string lastExitNode: ""
      property var preferredExitNodes: ([])
    }

    onLoadFailed: {
      cacheAdapter.lastExitNode = "";
      cacheAdapter.preferredExitNodes = [];
    }
  }

  Component.onCompleted: {
    Logger.i("Tailscale", "Service started");
    refresh();
  }

  // Save cache with debounce
  Timer {
    id: saveDebounce
    interval: 1000
    onTriggered: cacheFileView.writeAdapter()
  }

  function saveCache() {
    saveDebounce.restart();
  }

  // Status refresh timer - every 30s
  Timer {
    id: statusRefreshTimer
    interval: (pluginApi?.pluginSettings?.refreshInterval ?? 30) * 1000
    running: true
    repeat: true
    onTriggered: refresh()
  }

  Timer {
    id: quickRefreshTimer
    interval: 2000
    repeat: false
    onTriggered: refresh()
}

  // Core functions
  function refresh() {
    if (refreshing) return;
    refreshing = true;
    lastError = "";
    statusProcess.running = true;
  }

  function start() {
    if (togglingTailscale) return;
    togglingTailscale = true;
    lastError = "";
    startProcess.running = true;
  }

  function stop() {
    if (togglingTailscale) return;
    togglingTailscale = true;
    lastError = "";
    stopProcess.running = true;
  }

  function toggle() {
    if (running) stop();
    else start();
  }

  function setExitNode(nodeID, nodeName = "") {
    if (settingExitNode) return;
    settingExitNode = true;
    settingExitNodeTo = nodeName || nodeID;
    lastError = "";

    exitNodeProcess.nodeID = nodeID;
    exitNodeProcess.nodeName = nodeName;
    exitNodeProcess.running = true;
  }

  function clearExitNode() {
    setExitNode("", "");
  }

  function setShieldsUp(enabled) {
    shieldsUpProcess.enabled = enabled;
    shieldsUpProcess.running = true;
  }

  function setAcceptRoutes(enabled) {
    acceptRoutesProcess.enabled = enabled;
    acceptRoutesProcess.running = true;
  }

  function setAcceptDNS(enabled) {
    acceptDNSProcess.enabled = enabled;
    acceptDNSProcess.running = true;
  }

  function setExitNodeAllowLAN(enabled) {
    exitNodeAllowLANProcess.enabled = enabled;
    exitNodeAllowLANProcess.running = true;
  }

  function advertiseExitNode(enabled) {
    advertiseExitNodeProcess.enabled = enabled;
    advertiseExitNodeProcess.running = true;
  }

  function addPreferredExitNode(nodeID) {
    let prefs = cacheAdapter.preferredExitNodes;
    if (!prefs.includes(nodeID)) {
      prefs.push(nodeID);
      cacheAdapter.preferredExitNodes = prefs;
      saveCache();
    }
  }

  function removePreferredExitNode(nodeID) {
    let prefs = cacheAdapter.preferredExitNodes.filter(id => id !== nodeID);
    cacheAdapter.preferredExitNodes = prefs;
    saveCache();
  }

  // Helper functions
  function getDeviceByID(id) {
    return devices.find(d => d.id === id) || null;
  }

  function getDeviceByHostname(hostname) {
    return devices.find(d => d.hostname.toLowerCase() === hostname.toLowerCase()) || null;
  }

  function isPreferredExitNode(nodeID) {
    return cacheAdapter.preferredExitNodes.includes(nodeID);
  }

  function parseStatusData(data) {
    root.backendState = data.BackendState || "Unknown";
    root.connected = root.backendState === "Running";

    // Parse self node
    if (data.Self) {
      root.selfHostname = data.Self.HostName || "";
      root.selfID = data.Self.ID || "";
      root.selfOnline = data.Self.Online || false;

      // Get first IPv4 address
      const ips = data.Self.TailscaleIPs || [];
      root.selfIP = ips.find(ip => !ip.includes(":")) || ips[0] || "";

      // Check if we're advertising as exit node
      root.advertisingExitNode = (data.Self.ExitNode === true);
    }

    // Parse current exit node
    root.currentExitNode = (data.ExitNodeStatus && data.ExitNodeStatus.ID) ? data.ExitNodeStatus.ID : "";
    root.currentExitNodeName = "";

    // Parse peers
    const deviceList = [];
    const exitNodeList = [];
    const peers = data.Peer || {};

    for (const [id, peer] of Object.entries(peers)) {
      const ips = peer.TailscaleIPs || [];
      const device = {
        id: id,
        hostname: peer.HostName || "Unknown",
        dnsName: peer.DNSName || "",
        ip: ips.find(ip => !ip.includes(":")) || ips[0] || "",
        ipv6: ips.find(ip => ip.includes(":")) || "",
        os: peer.OS || "",
        online: peer.Online || false,
        lastSeen: peer.LastSeen || "",
        exitNode: peer.ExitNode || false,
        exitNodeOption: peer.ExitNodeOption || false,
        active: peer.Active || false,
        curAddr: peer.CurAddr || "",
        relay: peer.Relay || "",
        rxBytes: peer.RxBytes || 0,
        txBytes: peer.TxBytes || 0,
        tags: peer.Tags || []
      };

      deviceList.push(device);

      // Track exit nodes
      if (peer.ExitNodeOption) {
        exitNodeList.push(device);
      }

      // Track current exit node name
      if (peer.ExitNode && id === root.currentExitNode) {
        root.currentExitNodeName = peer.HostName || id;
      }
    }

    // Sort devices: online first, then by hostname
    deviceList.sort((a, b) => {
      if (a.online !== b.online) return b.online - a.online;
      return a.hostname.localeCompare(b.hostname);
    });

    // Sort exit nodes: preferred first, then online, then hostname
    exitNodeList.sort((a, b) => {
      const aPref = root.isPreferredExitNode(a.id);
      const bPref = root.isPreferredExitNode(b.id);
      if (aPref !== bPref) return bPref - aPref;
      if (a.online !== b.online) return b.online - a.online;
      return a.hostname.localeCompare(b.hostname);
    });

    root.devices = deviceList;
    root.exitNodes = exitNodeList;

    root.devicesChanged();

    Logger.d("Tailscale", `Status: ${root.backendState}, Devices: ${deviceList.length}, Exit nodes: ${exitNodeList.length}`);
  }

  function osIcon(os) {
    if (!os || typeof os !== "string") return "device-desktop";
    const osLower = os.toLowerCase();
    if (osLower.includes("linux")) return "device-desktop";
    if (osLower.includes("windows")) return "device-desktop";
    if (osLower.includes("macos") || osLower.includes("darwin")) return "device-laptop";
    if (osLower.includes("ios")) return "device-mobile";
    if (osLower.includes("android")) return "device-mobile";
    if (osLower.includes("freebsd")) return "server";
    return "device-desktop";
  }

  function statusIcon() {
    if (!root.connected) return "world-off";
    if (root.currentExitNode && root.currentExitNode !== "") return "shield-check";
    return "world-check";
  }

  function formatLastSeen(lastSeenStr) {
    if (!lastSeenStr) return "Never";
    const lastSeen = new Date(lastSeenStr);
    const now = new Date();
    const diffMs = now - lastSeen;
    const diffMins = Math.floor(diffMs / 60000);

    if (diffMins < 1) return "Just now";
    if (diffMins < 60) return `${diffMins}m ago`;

    const diffHours = Math.floor(diffMins / 60);
    if (diffHours < 24) return `${diffHours}h ago`;

    const diffDays = Math.floor(diffHours / 24);
    return `${diffDays}d ago`;
  }

  // Processes
  Process {
    id: statusProcess
    running: false
    command: ["tailscale", "status", "--json"]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(text);
          parseStatusData(data);
        } catch (e) {
          Logger.w("Tailscale", "Failed to parse status JSON: " + e);
          root.lastError = "Failed to parse status";
        }
        root.refreshing = false;
        root.loading = false;
      }
    }

    stderr: StdioCollector {
      onStreamFinished: {
        root.refreshing = false;
        root.loading = false;
        if (text.trim()) {
          // Check for common states
          if (text.includes("not running")) {
            root.connected = false;
            root.backendState = "Stopped";
            root.devices = [];
            root.exitNodes = [];

            root.devicesChanged();
          } else {
            Logger.w("Tailscale", "Status error: " + text);
            root.lastError = text.split("\n")[0].trim();
          }
        }
      }
    }
  }

  Process {
    id: startProcess
    running: false
    command: ["tailscale", "up"]

    stdout: StdioCollector {
      onStreamFinished: {
        root.togglingTailscale = false;
        Logger.i("Tailscale", "Started");
        ToastService.showNotice(pluginApi.tr("tailscale.title"), pluginApi.tr("toast.tailscale.started"), "world-check");
        // Refresh status after starting
        //statusRefreshTimer.interval = 2000;
        //statusRefreshTimer.restart();

        quickRefreshTimer.restart();
      }
    }

    stderr: StdioCollector {
      onStreamFinished: {
        root.togglingTailscale = false;
        if (text.trim()) {
          if (text.includes("needs login")) {
            root.backendState = "NeedsLogin";
            Logger.i("Tailscale", "Login required");
            ToastService.showWarning(pluginApi.tr("tailscale.title"), pluginApi.tr("toast.tailscale.needsLogin"));
          } else {
            Logger.w("Tailscale", "Start error: " + text);
            root.lastError = text.split("\n")[0].trim();
          }
        }
        refresh();
      }
    }
  }

  Process {
    id: stopProcess
    running: false
    command: ["tailscale", "down"]

    stdout: StdioCollector {
      onStreamFinished: {
        root.togglingTailscale = false;
        root.connected = false;
        root.currentExitNode = "";
        root.currentExitNodeName = "";
        Logger.i("Tailscale", "Stopped");
        ToastService.showNotice(pluginApi.tr("tailscale.title"), pluginApi.tr("toast.tailscale.stopped"), "world-off");
        refresh();
      }
    }

    stderr: StdioCollector {
      onStreamFinished: {
        root.togglingTailscale = false;
        if (text.trim()) {
          Logger.w("Tailscale", "Stop error: " + text);
          root.lastError = text.split("\n")[0].trim();
        }
        refresh();
      }
    }
  }

  Process {
    id: exitNodeProcess
    property string nodeID: ""
    property string nodeName: ""
    running: false
    command: nodeID ? ["tailscale", "set", "--exit-node=" + nodeID] : ["tailscale", "set", "--exit-node="]

    stdout: StdioCollector {
      onStreamFinished: {
        root.settingExitNode = false;
        root.settingExitNodeTo = "";

        if (exitNodeProcess.nodeID) {
          root.currentExitNode = exitNodeProcess.nodeID;
          root.currentExitNodeName = exitNodeProcess.nodeName;
          cacheAdapter.lastExitNode = exitNodeProcess.nodeID;
          saveCache();

          Logger.i("Tailscale", `Exit node set to: ${exitNodeProcess.nodeName || exitNodeProcess.nodeID}`);
          ToastService.showNotice(pluginApi.tr("tailscale.title"), pluginApi.tr("toast.tailscale.exitNodeSet", {
            "node": exitNodeProcess.nodeName || exitNodeProcess.nodeID
          }), "shield-check");
        } else {
          root.currentExitNode = "";
          root.currentExitNodeName = "";
          Logger.i("Tailscale", "Exit node cleared");
          ToastService.showNotice(pluginApi.tr("tailscale.title"), pluginApi.tr("toast.tailscale.exitNodeCleared"), "world-check");
        }

        refresh();
      }
    }

    stderr: StdioCollector {
      onStreamFinished: {
        root.settingExitNode = false;
        root.settingExitNodeTo = "";
        if (text.trim()) {
          Logger.w("Tailscale", "Exit node error: " + text);
          root.lastError = text.split("\n")[0].trim();
        }
        refresh();
      }
    }
  }

  Process {
    id: shieldsUpProcess
    property bool enabled: false
    running: false
    command: ["tailscale", "set", "--shields-up=" + (enabled ? "true" : "false")]

    stdout: StdioCollector {
      onStreamFinished: {
        root.shieldsUp = shieldsUpProcess.enabled;
        Logger.i("Tailscale", "Shields up: " + root.shieldsUp);
        ToastService.showNotice(pluginApi.tr("tailscale.title"),
          root.shieldsUp ? pluginApi.tr("toast.tailscale.shieldsUp") : pluginApi.tr("toast.tailscale.shieldsDown"),
          root.shieldsUp ? "shield-lock" : "shield");
      }
    }

    stderr: StdioCollector {
      onStreamFinished: {
        if (text.trim()) {
          Logger.w("Tailscale", "Shields up error: " + text);
          root.lastError = text.split("\n")[0].trim();
        }
      }
    }
  }

  Process {
    id: acceptRoutesProcess
    property bool enabled: false
    running: false
    command: ["tailscale", "set", "--accept-routes=" + (enabled ? "true" : "false")]

    stdout: StdioCollector {
      onStreamFinished: {
        root.acceptRoutes = acceptRoutesProcess.enabled;
        Logger.i("Tailscale", "Accept routes: " + root.acceptRoutes);
      }
    }

    stderr: StdioCollector {
      onStreamFinished: {
        if (text.trim()) {
          Logger.w("Tailscale", "Accept routes error: " + text);
          root.lastError = text.split("\n")[0].trim();
        }
      }
    }
  }

  Process {
    id: acceptDNSProcess
    property bool enabled: true
    running: false
    command: ["tailscale", "set", "--accept-dns=" + (enabled ? "true" : "false")]

    stdout: StdioCollector {
      onStreamFinished: {
        root.acceptDNS = acceptDNSProcess.enabled;
        Logger.i("Tailscale", "Accept DNS: " + root.acceptDNS);
      }
    }

    stderr: StdioCollector {
      onStreamFinished: {
        if (text.trim()) {
          Logger.w("Tailscale", "Accept DNS error: " + text);
          root.lastError = text.split("\n")[0].trim();
        }
      }
    }
  }

  Process {
    id: exitNodeAllowLANProcess
    property bool enabled: false
    running: false
    command: ["tailscale", "set", "--exit-node-allow-lan-access=" + (enabled ? "true" : "false")]

    stdout: StdioCollector {
      onStreamFinished: {
        root.exitNodeAllowLANAccess = exitNodeAllowLANProcess.enabled;
        Logger.i("Tailscale", "Exit node allow LAN: " + root.exitNodeAllowLANAccess);
      }
    }

    stderr: StdioCollector {
      onStreamFinished: {
        if (text.trim()) {
          Logger.w("Tailscale", "Exit node allow LAN error: " + text);
          root.lastError = text.split("\n")[0].trim();
        }
      }
    }
  }

  Process {
    id: advertiseExitNodeProcess
    property bool enabled: false
    running: false
    command: ["tailscale", "set", "--advertise-exit-node=" + (enabled ? "true" : "false")]

    stdout: StdioCollector {
      onStreamFinished: {
        root.advertisingExitNode = advertiseExitNodeProcess.enabled;
        Logger.i("Tailscale", "Advertising exit node: " + root.advertisingExitNode);
        ToastService.showNotice(pluginApi.tr("tailscale.title"),
          root.advertisingExitNode ? pluginApi.tr("toast.tailscale.advertisingExitNode") : pluginApi.tr("toast.tailscale.notAdvertisingExitNode"),
          "router");
      }
    }

    stderr: StdioCollector {
      onStreamFinished: {
        if (text.trim()) {
          Logger.w("Tailscale", "Advertise exit node error: " + text);
          root.lastError = text.split("\n")[0].trim();
        }
      }
    }
  }

  // Process to get current preferences (run on startup)
  Process {
    id: prefsProcess
    running: false
    command: ["tailscale", "debug", "prefs"]

    Component.onCompleted: running = true

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const prefs = JSON.parse(text);
          root.shieldsUp = prefs.ShieldsUp || false;
          root.acceptRoutes = prefs.RouteAll || false;
          root.acceptDNS = prefs.CorpDNS !== false;
          root.exitNodeAllowLANAccess = prefs.ExitNodeAllowLANAccess || false;
          Logger.d("Tailscale", "Loaded preferences");
        } catch (e) {
          Logger.w("Tailscale", "Failed to parse prefs: " + e);
        }
      }
    }
  }
}
