import Foundation

// The words of the crew and "Who has access" screens, in one place. They
// follow the shared look's word list (words.crew and words.access) word for
// word; the few that only this app needs are marked "app only".
enum HubWords {
    // What the app calls the thing a streamer owns and lets people into.
    // Every screen here takes the word from these two, so it changes in
    // one place.
    static let setupName = String(localized: "your streaming setup")
    static let setupShort = String(localized: "setup")

    enum Crew {
        static let title = String(localized: "Crew")
        static let helperLink = String(localized: "Helper link")
        static let makeHelper = String(localized: "Make helper link")
        static let makeMod = String(localized: "Make mod link")
        static let makeLink = String(localized: "Make link")
        static let mods = String(localized: "Mods")
        static let links = String(localized: "Open helper links")
        static let expiry = String(localized: "Link lasts")
        static let endLink = String(localized: "End link")
        static let copy = String(localized: "Copy link")
        static let copied = String(localized: "Copied")
        static let name = String(localized: "Mod name")
        static let personName = String(localized: "Who is it for?")
        static let waiting = String(localized: "Waiting to open")
        static let joined = String(localized: "Joined")
        static let since = String(localized: "Since")
        static let until = String(localized: "Until")
        static let helperHint = String(localized: "Works once. The helper waits for Allow.")
        static let modHint = String(localized: "Works once. Status and HIDE only.")
        static let emptyMods = String(localized: "No mod links.")
        static let emptyLinks = String(localized: "No open helper links.")
        static let accessEnds = String(localized: "Access ends")
        static let tonight = String(localized: "When the stream ends")
        static let accessDuration = String(localized: "After they join")
        static let unconfirmed = String(localized: "Can't confirm that change. Check the list before trying again.")

        static func hiddenBy(_ name: String) -> String {
            String(localized: "Hidden by \(name)")
        }

        // App only.
        static let helpers = String(localized: "Helpers")
        static let emptyHelpers = String(localized: "No helpers.")
        static let share = String(localized: "Share link")
        static let done = String(localized: "Done")
        static let shownOnce = String(localized: "This link is shown only now. Share it before you close this.")
        static let modName = String(localized: "Mod")
        static let noModLinks =
            String(localized: "This hub can't make mod links yet. A mod's page needs an https address.")
        static let qrLabel = String(localized: "The link as a code to scan")

        static func wantsToHelp(_ name: String) -> String {
            String(localized: "\(name) wants to help")
        }

        static func wantsToJoin(_ name: String) -> String {
            String(localized: "\(name) wants to join")
        }

        static func hid(_ name: String) -> String {
            String(localized: "\(name) hid the picture")
        }
    }

    enum Access {
        static let title = String(localized: "Who has access")
        static let waiting = String(localized: "Waiting for Allow")
        static let yours = String(localized: "Your devices")
        static let helpers = String(localized: "Helpers")
        static let mods = String(localized: "Mods")
        static let invites = String(localized: "Invites not used yet")
        static let trail = String(localized: "What happened")

        static func role(_ role: String) -> String {
            switch role {
            case "admin":
                String(localized: "Owner device")
            case "member":
                String(localized: "Your device")
            case "helper":
                String(localized: "Helper")
            case "mod":
                String(localized: "Mod")
            case "shared":
                String(localized: "Device")
            case "session":
                String(localized: "Stream session owner")
            default:
                role
            }
        }

        // One phrase per request the hub checks; a role's sentence is built
        // from the requests the hub says it may make.
        static let can: [(String, String)] = [
            ("stream.go_live", String(localized: "go live")),
            ("stream.move", String(localized: "move the stream")),
            ("stream.end", String(localized: "end the stream")),
            ("privacy.hide", String(localized: "hide the picture")),
            ("privacy.show", String(localized: "show the picture again")),
            ("invite.open", String(localized: "let people in and remove them")),
        ]
        static let cantManage = String(localized: "let people in or remove them")
        static let canForStream = String(localized: "let helpers and mods in for this stream only")
        static let cantOwner: [(String, String)] = [
            ("device.remove", String(localized: "remove devices or owners")),
            ("hub.recovery.get", String(localized: "see keys or passwords")),
        ]

        static let others = String(localized: "Other devices")
        static let thisStream = String(localized: "This stream")
        static let you = String(localized: "You")

        static func youNamed(_ name: String) -> String {
            String(localized: "\(name) (you)")
        }

        static let unnamed = String(localized: "Co-owner")
        static let unnamedLower = String(localized: "co-owner")
        static let owner = String(localized: "Owner")
        static let coOwner = String(localized: "Co-owner")

        static func noteNewOwner(_ person: String) -> String {
            String(localized: "Allowing makes \(person) a co-owner.")
        }

        static func noteOtherOwner(_ person: String) -> String {
            String(localized: "Allowing adds an owner device for \(person).")
        }

        static let noteHandsStream = String(localized: "Allowing hands this stream to them.")
        static let noteRuns =
            String(localized: "Runs this stream. That ends with the stream, and so does everything they let in.")
        static let noteBySession =
            String(localized: "Let in by the stream's session owner. Ends when they stop running it.")

        static func noteInviteOwner(_ person: String) -> String {
            String(localized: "Whoever joins with it becomes an owner device for \(person), once an owner confirms.")
        }

        static let noteInviteHand = String(localized: "Whoever joins with it is handed this stream once allowed.")

        static let runOwners =
            String(localized: "The owners run it. To let someone else run it, hand it over on their row.")

        static func runWentLive(_ who: String, _ device: String) -> String {
            String(localized: "\(who) went live from \(device) and runs it.")
        }

        static func runWentLiveDevice(_ device: String) -> String {
            String(localized: "\(device) went live and runs it.")
        }

        static func runHanded(_ who: String, _ device: String) -> String {
            String(localized: "\(who) runs it, on \(device).")
        }

        static func runHandedDevice(_ device: String) -> String {
            String(localized: "\(device) runs it.")
        }

        static func runBy(_ by: String, _ when: String) -> String {
            String(localized: "Handed over by \(by) · \(when)")
        }

        static func runEnds(_ when: String) -> String {
            String(localized: "Ends when the stream ends, or \(when)")
        }

        static func runGave(_ list: String) -> String {
            String(localized: "Let in for this stream: \(list). They end with it.")
        }

        static let cancel = String(localized: "Cancel")
        static let handOver = String(localized: "Hand over this stream")
        static let takeBack = String(localized: "Take back")
        static let makeCoOwner = String(localized: "Make co-owner")
        static let clear = String(localized: "Clear")

        static func confirmCoOwner(_ person: String, _ name: String) -> String {
            String(localized: "Make \(person) a co-owner with \(name)? A co-owner can do everything you can, including removing your devices.")
        }

        static func confirmHandOver(_ name: String) -> String {
            String(localized: "Hand this stream to \(name)? They can go live, move, end, hide and show, and let helpers and mods in for this stream. It ends with the stream, or when you take it back.")
        }

        static func confirmTakeBack(_ name: String) -> String {
            String(localized: "Take this stream back from \(name)? The stream keeps running.")
        }

        static func confirmTakeBackGave(_ name: String, _ list: String) -> String {
            String(localized: "Take this stream back from \(name)? What they let in (\(list)) loses access at once. The stream keeps running.")
        }

        static let confirmClear =
            String(localized: "Clear what happened? The lines are gone for every owner. One line stays to say who cleared them.")
        // App only: the hub is set to need two owners for this.
        static let secondOwner = String(localized: "This needs a second owner's yes. Nothing was changed.")
        static let canAll = String(localized: "Can do everything, and let people in and remove them.")

        static func canOnly(_ list: String) -> String {
            String(localized: "Can see the status and \(list). Nothing else.")
        }

        static func canSome(_ can: String, _ cant: String) -> String {
            String(localized: "Can \(can). Can't \(cant).")
        }

        static let here = String(localized: "Here now")
        static let away = String(localized: "Away")
        static let pageOpen = String(localized: "Page open")
        static let pageClosed = String(localized: "Page closed")
        static let notOpened = String(localized: "Link not opened yet")

        static func howScan(_ by: String) -> String {
            String(localized: "Scanned a code on \(by)")
        }

        static func howLink(_ by: String) -> String {
            String(localized: "Opened a link from \(by)")
        }

        static func howLinkAllowed(_ by: String, _ allowed: String) -> String {
            String(localized: "Opened a link from \(by), allowed by \(allowed)")
        }

        static func howWebLink(_ by: String) -> String {
            String(localized: "Web link made on \(by)")
        }

        static let howFirstLink = String(localized: "Joined with the hub's first link")
        static let howUnknown = String(localized: "Joined")

        static func howInviteScan(_ by: String) -> String {
            String(localized: "Code shown on \(by)")
        }

        static func howInviteLink(_ by: String) -> String {
            String(localized: "Link made on \(by)")
        }

        static let anOwnerDevice = String(localized: "an owner device")

        static let endsNever = String(localized: "Until you remove it")

        static func endsAt(_ when: String) -> String {
            String(localized: "Ends \(when)")
        }

        static let endsStream = String(localized: "Ends when the stream ends")

        static func endsStreamOrAt(_ when: String) -> String {
            String(localized: "Ends when the stream ends, or \(when)")
        }

        static func inviteAt(_ when: String) -> String {
            String(localized: "Closes \(when) if nobody uses it")
        }

        static func inviteGives(_ until: String) -> String {
            String(localized: "Whoever joins with it stays \(until).")
        }

        static let inviteStream = String(localized: "until the stream ends")

        static func inviteHours(_ hours: String) -> String {
            String(localized: "for \(hours) hours")
        }

        static func inviteMinutes(_ minutes: String) -> String {
            String(localized: "for \(minutes) minutes")
        }

        static let carries = String(localized: "Viewers see this device. Removing it puts the standby picture on.")
        static let lastOwner = String(localized: "The last owner device can't be removed.")
        // App only: the web page says "This page acts for this device."
        static let thisPhone = String(localized: "This phone.")

        static let allow = String(localized: "Allow")
        static let remove = String(localized: "Remove")
        static let endNow = String(localized: "End now")
        static let keep = String(localized: "Keep")
        static let change = String(localized: "Change when it ends")
        static let older = String(localized: "Show older")

        static func confirmRemove(_ name: String) -> String {
            String(localized: "Remove \(name)? It loses access at once.")
        }

        static func confirmRemoveCarrier(_ name: String) -> String {
            String(localized: "Remove \(name)? Viewers see it right now, so the standby picture goes on.")
        }

        static func confirmEndMod(_ name: String) -> String {
            String(localized: "End \(name)'s mod link? Their page closes at once.")
        }

        static let confirmEndInvite = String(localized: "Close this invite? The code or link stops working.")

        static let changeStream = String(localized: "When the stream ends")
        static let changeHour = String(localized: "In 1 hour")
        static let changeHalfDay = String(localized: "In 12 hours")
        static let changeDay = String(localized: "In 24 hours")
        static let changeNever = String(localized: "Until you remove it")

        static let failed = String(localized: "That didn't reach the hub. Try again.")
        static let emptyTrail = String(localized: "Nothing yet.")

        static let streamReady = String(localized: "Ready")
        static let streamLive = String(localized: "LIVE")
        static let streamHidden = String(localized: "LIVE · privacy screen on")
        static let streamEnded = String(localized: "Stream ended")

        static let unknownTitle = String(localized: "Can't say right now")
        static let unknownLine = String(localized: "Lost the connection to your hub. Reconnecting…")
    }

    static func duration(_ duration: HubLinkDuration) -> String {
        switch duration {
        case .minute:
            String(localized: "1 minute")
        case .halfHour:
            String(localized: "30 minutes")
        case .twoHours:
            String(localized: "2 hours")
        case .halfDay:
            String(localized: "12 hours")
        case .day:
            String(localized: "1 day")
        case .week:
            String(localized: "7 days")
        }
    }
}

// How long a link stays open, or how long access lasts once someone joins.
enum HubLinkDuration: String, CaseIterable, Identifiable {
    case minute
    case halfHour
    case twoHours
    case halfDay
    case day
    case week

    var id: String {
        rawValue
    }

    var milliseconds: Int {
        switch self {
        case .minute:
            60000
        case .halfHour:
            30 * 60000
        case .twoHours:
            2 * 3_600_000
        case .halfDay:
            12 * 3_600_000
        case .day:
            24 * 3_600_000
        case .week:
            7 * 24 * 3_600_000
        }
    }
}
