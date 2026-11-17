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

    enum Setup {
        static let panelTitle = String(localized: "Setup")
        static let yours = String(localized: "Your setup")
        static let joinTitle = String(localized: "Join your setup")
        static let joinLine = String(localized: "Scan the code on your dashboard, or open the link you were sent.")
        static let waitingLine = String(localized: "Someone in the setup has to allow this device.")
        static let crewLine =
            String(localized: "Everyone and everything in your streaming setup. Each device has its own key.")
        static let crewLineHelper = String(localized: "Everyone in the streamer's setup.")
        static let setBy = String(localized: "Set by your setup")
        static let leave = String(localized: "Leave this setup")
        static let leaveLine = String(localized: "The stream settings from the setup are removed from this phone.")
        static let leaveHint =
            String(localized: "Nothing to type or change. Leaving the setup removes it from this phone.")
        static let settingsGone = String(localized: "Its stream settings from the setup are gone.")
        static let notASetupCode = String(localized: "This code isn't from a setup's hub")
        static let cantJoinWhileStreaming = String(localized: "Can't join a setup while streaming or recording")
        static let sentLink = String(localized: "Or tap the link in the message someone in the setup sent you.")
        static let joinHint =
            String(localized: "Nothing to type. The code is a one-time ticket, and your setup fills in this phone's stream settings.")

        static func streamName(_ hub: String) -> String {
            String(localized: "Setup: \(hub)")
        }
    }

    enum Crew {
        static let title = String(localized: "Crew")
        static let helperLink = String(localized: "Helper link")
        static let makeLink = String(localized: "Make link")
        static let expiry = String(localized: "Link lasts")
        static let endLink = String(localized: "End link")
        static let copy = String(localized: "Copy link")
        static let copied = String(localized: "Copied")
        static let personName = String(localized: "Who is it for?")
        static let accessEnds = String(localized: "Access ends")
        static let tonight = String(localized: "When the stream ends")
        static let unconfirmed = String(localized: "Can't confirm that change. Check the list before trying again.")
        static let another = String(localized: "Make another")
        static let done = String(localized: "Done")
        static let cancel = String(localized: "Cancel")
        static let linkPlain = String(localized: "Helper link")
        static let notOpened = String(localized: "Not opened yet")
        static let accessLine = String(localized: "What each can do, since when and until when, and what happened.")
        static let runs = String(localized: "Runs this stream")
        static let thisPhone = String(localized: "this phone")
        static let present = String(localized: "Connected")
        static let away = String(localized: "Away")
        static let endsStream = String(localized: "ends with the stream")

        static let groupDevices = String(localized: "Devices")
        static let groupHelpers = String(localized: "Helpers")
        static let groupMods = String(localized: "Mods")
        static let groupCoOwners = String(localized: "Co-owners")
        static let addHelper = String(localized: "Add a helper")
        static let addMod = String(localized: "Add a mod")
        static let addCoOwner = String(localized: "Add a co-owner")
        static let emptyHelpers = String(localized: "No helpers. A helper gets the status, HIDE and Move stream.")
        static let emptyMods = String(localized: "No mods. A mod gets the status and HIDE on a web page.")
        static let emptyCoOwners = String(localized: "Nobody else owns this setup.")

        static func hiddenBy(_ name: String) -> String {
            String(localized: "Hidden by \(name)")
        }

        static func linkFor(_ name: String) -> String {
            String(localized: "Link for \(name)")
        }

        static func sinceAt(_ when: String) -> String {
            String(localized: "since \(when)")
        }

        static func endsAt(_ when: String) -> String {
            String(localized: "ends \(when)")
        }

        static func endsStreamOr(_ when: String) -> String {
            String(localized: "ends with the stream, or \(when)")
        }

        static func closesAt(_ when: String) -> String {
            String(localized: "closes \(when)")
        }

        static func wants(_ device: String, _ role: String) -> String {
            String(localized: "“\(device)” wants to join as a \(role)")
        }

        static let wantsLine = String(localized: "It joined with a link that was sent, not scanned here.")
        static let wantsHand = String(localized: "Allowing hands this stream to them.")

        static let helperLine =
            String(localized: "Make a link and send it. It works once, and they wait for your Allow.")
        static let handStream = String(localized: "Let them run this stream")
        static let handStreamHint =
            String(localized: "They can go live, move, end, hide and show, and let helpers and mods in for this stream only. It ends with the stream.")

        static func helperReady(_ name: String) -> String {
            name.isEmpty ? String(localized: "Send this link to your helper.")
                : String(localized: "Send this link to \(name).")
        }

        static let helperNext = String(localized: "When they open it, they wait here for your Allow.")
        static let afterHour = String(localized: "1 hour after they join")
        static let afterHalfDay = String(localized: "12 hours after they join")
        static let afterDay = String(localized: "24 hours after they join")
        static let untilRemoved = String(localized: "When you remove them")

        static func helperCloses(_ when: String) -> String {
            String(localized: "Closes \(when) if nobody uses it.")
        }

        static let modLine =
            String(localized: "A web link for one person: the status and HIDE, nothing else. No app and no Allow.")
        static let modEnds = String(localized: "Link ends")
        static let modTonightHint = String(localized: "At the latest after 12 hours.")

        static func modReady(_ name: String) -> String {
            String(localized: "Send this link to \(name).")
        }

        static let modNext = String(localized: "It opens once, in the first browser that uses it.")

        static func modLinkLabel(_ name: String) -> String {
            String(localized: "Mod link for \(name)")
        }

        static func modCloses(_ when: String) -> String {
            String(localized: "The link ends \(when).")
        }

        static let coOwnerLine =
            String(localized: "For someone who shares this setup for good, like a housemate. A co-owner can do everything you can, including removing your devices.")
        static let coOwnerName = String(localized: "Their name")
        static let yourName = String(localized: "Your name, as the others see it")
        static let yourNameHint = String(localized: "So the list reads by person, not by device.")
        static let coOwnerShow = String(localized: "Show their code")
        static let coOwnerNext =
            String(localized: "After they scan it, you confirm once more here. Nothing is shared until then.")
        static let coOwnerNextKnown = String(localized: "After they scan it, you allow the device here.")
        static let coOwnerWho = String(localized: "Who is it for?")
        static let someoneNew = String(localized: "Someone new")

        static func coOwnerAnother(_ name: String) -> String {
            String(localized: "\(name): another owner device")
        }

        static func coOwnerLink(_ name: String, _ when: String) -> String {
            String(localized: "\(name) scans this with their device, or opens the link on it. It works once and closes \(when).")
        }

        static func coOwnerWants(_ device: String) -> String {
            String(localized: "“\(device)” wants to join as a co-owner’s device")
        }

        static func coOwnerWantsOwn(_ device: String, _ person: String) -> String {
            String(localized: "“\(device)” wants to join as an owner device for \(person)")
        }

        static func ownerAdded(_ device: String, _ person: String) -> String {
            String(localized: "\(device) is now an owner device for \(person).")
        }

        static func ownerAddedNew(_ person: String, _ device: String) -> String {
            String(localized: "\(person) is now a co-owner, with \(device).")
        }

        static func ownerRemoved(_ by: String, _ device: String, _ person: String) -> String {
            String(localized: "\(by) removed \(device), an owner device for \(person).")
        }

        static func ownerRemovedLeft(_ by: String, _ device: String, _ person: String) -> String {
            String(localized: "\(by) removed \(device). \(person) is no longer an owner.")
        }

        static func handed(_ by: String) -> String {
            String(localized: "\(by) handed you this stream. You can go live, move, end, hide and show, and let helpers and mods in for it.")
        }

        static func takenBack(_ why: String?) -> String {
            switch why {
            case "returned":
                String(localized: "You gave the stream back.")
            case "stream":
                String(localized: "The stream ended, and with it your handover.")
            case "time":
                String(localized: "Your handover ran out at its set time.")
            case "handed_on":
                String(localized: "The stream was handed to someone else.")
            case "taken_back":
                String(localized: "The stream was taken back. You are a helper again.")
            default:
                String(localized: "Your handover ended.")
            }
        }

        static let giveBack = String(localized: "Give the stream back")
        static let giveBackConfirm =
            String(localized: "Give this stream back to the owners? What you let in loses access at once. The stream keeps running.")
        static let youRun = String(localized: "You run this stream until it ends.")

        static let thisStream = String(localized: "This stream")

        static func streamHanded(_ device: String) -> String {
            String(localized: "\(device) runs this stream.")
        }

        static func streamHandedFor(_ who: String, _ device: String) -> String {
            String(localized: "\(who) runs this stream, on \(device).")
        }

        static func streamUntil(_ when: String) -> String {
            String(localized: "Until the stream ends, or \(when).")
        }

        static func refused(_ code: String) -> String? {
            switch code {
            case "confirm_needed":
                String(localized: "That makes someone a co-owner. Read the question, then confirm.")
            case "second_owner_needed":
                String(localized: "That needs a second owner's yes.")
            case "last_admin":
                String(localized: "The last owner device can't be removed.")
            case "unavailable":
                String(localized: "This hub can't make that link: its web address isn't https.")
            case "too_many":
                String(localized: "That's as many open links as one device can have. End one first.")
            default:
                nil
            }
        }

        static let share = String(localized: "Share link")
        static let shownOnce = String(localized: "This link is shown only now. Share it before you close this.")
        static let modName = String(localized: "Mod")
        static let qrLabel = String(localized: "The link as a code to scan")
        static let yourNameTitle = String(localized: "Your name")
        static let save = String(localized: "Save")
        static let notOwner = String(localized: "Only an owner device can let people in or remove them.")
        static let ok = String(localized: "OK")

        static func wantsOwner(_ device: String) -> String {
            String(localized: "“\(device)” wants to join as an owner device")
        }

        static let alreadyHidden = String(localized: "Already hidden")

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
        static let links = String(localized: "Links to this page")

        static func linkName(_ device: String) -> String {
            String(localized: "Made on \(device)")
        }

        static let linkOpen = String(localized: "Page open")
        static let linkClosed = String(localized: "Page closed")
        static let linkNotOpened = String(localized: "Not opened yet")

        static func linkMade(_ when: String) -> String {
            String(localized: "Made \(when)")
        }

        static func linkOpened(_ made: String, _ opened: String) -> String {
            String(localized: "Made \(made) · opened \(opened)")
        }

        static func linkEnds(_ when: String) -> String {
            String(localized: "Ends \(when)")
        }

        static let linkCan = String(localized: "Whoever holds it sees this list and can remove people and devices.")
        static let linkConfirm = String(localized: "End this link? The page it opened closes at once.")

        static func theirs(_ person: String) -> String {
            String(localized: "\(person) allows this on one of their own devices.")
        }

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
            String(localized: "Clear what happened? The lines are gone for every owner. The lines about owners stay, and one line says who cleared the rest.")
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
        case .hour:
            String(localized: "1 hour")
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
    case hour
    case twoHours
    case halfDay
    case day
    case week

    var id: String {
        rawValue
    }

    static let linkChoices: [HubLinkDuration] = [.minute, .halfHour, .twoHours, .halfDay, .day, .week]

    var milliseconds: Int {
        switch self {
        case .minute:
            60000
        case .halfHour:
            30 * 60000
        case .hour:
            3_600_000
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
