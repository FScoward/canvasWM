import Foundation

public final class PTYSession {
    private var masterFd: Int32 = -1
    private var childPid: pid_t = 0
    private var readSource: DispatchSourceRead?
    public var onOutput: ((String) -> Void)?
    public var onExit: ((Int32) -> Void)?
    public private(set) var isAlive: Bool = false

    public init() {}

    public func start(cols: UInt16 = 80, rows: UInt16 = 24) {
        var winSize = winsize(ws_row: rows, ws_col: cols, ws_xpixel: 0, ws_ypixel: 0)
        var slaveFd: Int32 = 0

        childPid = forkpty(&masterFd, nil, nil, &winSize)

        if childPid == 0 {
            // Child process
            let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
            let env = [
                "TERM=xterm-256color",
                "COLORTERM=truecolor",
                "HOME=\(NSHomeDirectory())",
                "PATH=\(ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin")",
                "LANG=en_US.UTF-8"
            ]
            let cEnv = env.map { strdup($0) } + [nil]
            let args = [strdup(shell), strdup("-l"), nil]
            execve(shell, args, cEnv)
            _exit(1)
        } else if childPid > 0 {
            isAlive = true
            startReading()
            monitorChild()
        }
    }

    private func startReading() {
        let source = DispatchSource.makeReadSource(fileDescriptor: masterFd, queue: .global(qos: .userInteractive))
        source.setEventHandler { [weak self] in
            guard let self, self.masterFd >= 0 else { return }
            var buffer = [UInt8](repeating: 0, count: 4096)
            let bytesRead = read(self.masterFd, &buffer, buffer.count)
            if bytesRead > 0 {
                let str = String(bytes: buffer[0..<bytesRead], encoding: .utf8) ?? ""
                if !str.isEmpty {
                    DispatchQueue.main.async { self.onOutput?(str) }
                }
            }
        }
        source.setCancelHandler { [weak self] in
            guard let self else { return }
            if self.masterFd >= 0 { close(self.masterFd); self.masterFd = -1 }
        }
        source.resume()
        readSource = source
    }

    private func monitorChild() {
        DispatchQueue.global().async { [weak self] in
            guard let self else { return }
            var status: Int32 = 0
            waitpid(self.childPid, &status, 0)
            DispatchQueue.main.async {
                self.isAlive = false
                self.onExit?(status)
            }
        }
    }

    public func write(_ data: String) {
        guard masterFd >= 0 else { return }
        data.withCString { ptr in
            let len = strlen(ptr)
            Darwin.write(masterFd, ptr, len)
        }
    }

    public func resize(cols: UInt16, rows: UInt16) {
        guard masterFd >= 0 else { return }
        var winSize = winsize(ws_row: rows, ws_col: cols, ws_xpixel: 0, ws_ypixel: 0)
        ioctl(masterFd, TIOCSWINSZ, &winSize)
    }

    public func terminate() {
        readSource?.cancel()
        readSource = nil
        if childPid > 0 { kill(childPid, SIGHUP) }
        if masterFd >= 0 { close(masterFd); masterFd = -1 }
        isAlive = false
    }

    public func getCwd() -> String? {
        guard childPid > 0 else { return nil }
        let path = "/proc/\(childPid)/cwd"
        if let resolved = try? FileManager.default.destinationOfSymbolicLink(atPath: path) {
            return resolved
        }
        // macOS fallback: use proc_pidinfo
        var pathInfo = proc_vnodepathinfo()
        let size = MemoryLayout<proc_vnodepathinfo>.size
        let result = proc_pidinfo(childPid, PROC_PIDVNODEPATHINFO, 0, &pathInfo, Int32(size))
        if result == Int32(size) {
            return withUnsafePointer(to: pathInfo.pvi_cdir.vip_path) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { String(cString: $0) }
            }
        }
        return nil
    }

    deinit { terminate() }
}
