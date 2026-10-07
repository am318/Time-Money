import Foundation

/// Presets set labels, defaults and which fields start visible. The engine
/// underneath is identical for every one of them — which is exactly why the
/// list must never be the way in. It's a convenience, not a gate.
enum ScenarioKind: String, Codable, CaseIterable, Identifiable {

    // Comes up constantly
    case fasterVsCheaper, paySomeoneElse, deliverVsCollect, parkingCloseVsFar
    case skipTheQueue, eatOutVsCook, coffeeOutVsHome, driveOrTrain, inPersonOrRemote

    // Comes up monthly
    case switchProvider, subscription, bulkBuy, fixTheFriction, groceries

    // Is this worth paying for?
    case gymVsPayg, seasonTicket, annualVsMonthly, buyNowVsWait
    case extendedWarranty, claimVsPay, buyOrRent, payForSpeed
    case buyOutrightVsSubscribe, costPerUse, paysYouBack, buyOnceBetterForever

    // Once in a while
    case buyRepairDoWithout, returnAnItem, experience, upgradeQuality, socialEvent
    case extraWork, dropAnIncome, sellStuff, shopAround, diyVsHire, squeezeItIn, unplannedWork
    case secondHandVsNew, payForAdmin, dayOffForAdmin, babysitterTax, learnItOnce
    case sellIndividuallyVsBulk

    // Life-sized
    case commuteVsRent, fourDayWeek, salaryVsCommute, childcareVsHours
    case trainingForPay, carOwnership, takeALodger

    case custom

    var id: String { rawValue }
    var template: ScenarioTemplate { ScenarioTemplate.all[self] ?? ScenarioTemplate.fallback }
}

struct ScenarioTemplate {
    let title: String
    let symbol: String
    let blurb: String
    let family: Family
    let optionA: String
    let optionB: String
    let directionA: MoneyDirection
    let directionB: MoneyDirection
    let frequency: Frequency
    let showsSetup: Bool
    let setupLabel: String
    /// How often the setup fields recur. Rent is monthly even when the commute is daily.
    var setupFrequency: Frequency = .once
    /// How far out to count by default. A year suits most things and is badly wrong
    /// for anything bought once that then keeps going: a year is the only window in
    /// which a perpetual licence can't beat a subscription, and a coat worn weekly
    /// is 46p a wear over five years and £2.31 over one.
    var horizonMonths: Double = 12
    /// Which way the one-off money flows, where that differs from the recurring money.
    /// Course fees leave you once; the pay rise they buy arrives every month after.
    var setupDirectionA: MoneyDirection? = nil
    var setupDirectionB: MoneyDirection? = nil
    /// Whether this is a going-somewhere decision, where timetables apply.
    var involvesTravel: Bool = false
    /// Whether other people are involved, so that what it means to them is a question
    /// worth putting. A dishwasher does not have feelings about being bought.
    var involvesOthers: Bool = false
    /// Whether there's a task here you could get better at. Rules out asking whether
    /// a party teaches you anything.
    var involvesEffort: Bool = false
    /// Whether there is something here that can fail to be delivered, so that "how
    /// often does each let you down" is a question about the options rather than about
    /// life in general. A cancelled train is a real cost; a birthday party does not
    /// have a reliability record, and asking after one reads as a category error —
    /// whether a night out turns out to be any good is `joyOdds`, not this.
    var canGoWrong: Bool = false
    /// Whether this is a chance that might not come round again. Scarcity is a strong
    /// multiplier — two and a half times, at the top — and it lifts enjoyment only, so
    /// it belongs to occasions and not to errands. The nearer parking space may well
    /// be nicer; it is not a once-in-a-lifetime nicer.
    var isAnOccasion: Bool = false
    /// Whether each side is something you do a countable number of times in a period —
    /// a trip, a wear, a meal, a journey — rather than a standing arrangement charged
    /// once per period. "How many times each" multiplies an option's money and its time
    /// together, which is right for three trips to the shop and nonsense for rent: you
    /// can make three trips in a week, and you cannot have three lodgers in one spare
    /// room. `showsTimesEach` is the subset obvious enough to put on the form.
    var isCountable: Bool = false
    /// Whether each side's recurring money is charged per go or per period, where that
    /// differs between them. A membership is billed monthly however often you turn up;
    /// the pay-as-you-go swim next to it is charged per swim. Nil means per go, which
    /// is what "cost" plainly means and is right for the other forty-nine.
    var chargedEachTimeA: Bool? = nil
    var chargedEachTimeB: Bool? = nil
    /// Whether the one-off field is the number this decision is made of, rather than a
    /// side charge next to a monthly one. The purchase price, the course fees, the
    /// excess — where it is the headline figure the cursor should start there, because
    /// the field above it is charged every period and the difference is the whole bug
    /// this scenario exists to avoid.
    var startsOnTheOneOff: Bool = false

    /// Show the "how many times each" field up front, for decisions where the two
    /// sides plainly don't happen at the same rate.
    var showsTimesEach: Bool = false
    /// Show "how long each one lasts". Only for decisions that turn on durability,
    /// where the two sides wear out at different rates.
    var showsLifespan: Bool = false
    /// Show the one-off time row on its own, for decisions where hours are spent once
    /// and no money is. Finding and vetting a cleaner is real effort, and leaving it
    /// out quietly flatters every option that involves arranging something.
    var showsSetupTime: Bool = false
    /// What to call that row. Nil derives it: "One-off time", or the cadence when the
    /// one-off fields actually recur — a row labelled "One-off" and charged monthly is
    /// the same lie as a price charged twelve times.
    var setupTimeLabel: String? = nil
    let hint: String
    /// True when the natural shape is "should I, or not?" rather than "A or B?".
    var isYesNo: Bool = false
    /// Whether that second side is genuinely nothing, or a thing in its own right.
    ///
    /// "Don't" is nothing and a card asking how it would feel is noise. "Leave it and
    /// rest", "Keep the time", "Keep the place to myself" are not nothing — they are
    /// the other half of the decision, and hiding them meant the app scored resting at
    /// zero against a late gym session marked tiring, and privacy at zero on a scenario
    /// whose own hint says the feel slider decides it. The planner had always modelled
    /// a second side; only the screen left it out.
    var secondSideIsBlank: Bool = false
    /// Questions this decision cannot be answered without, asked whether or not they
    /// change the verdict.
    ///
    /// The rule everywhere else — ask only what could move the answer — is the right
    /// one, and for a warranty it fails completely: £60 of cover against £0 is decisive
    /// on price alone, nothing flips, and so the app never asks how likely the thing is
    /// to break. It settles the question by pricing the cover and ignoring the risk,
    /// which is the one calculation a warranty scenario exists to avoid. These are not
    /// nuances to be earned; they are the facts the app cannot guess and cannot do
    /// without. They still count against the three-question cap.
    var essentialQuestions: [QuestionKind] = []
    /// Whether the option labels name the choice, or merely illustrate it.
    ///
    /// "Buy it outright" names it. "e.g. Uber" is a suggestion for a field you are meant
    /// to fill in yourself, and "Option A" names nothing at all — for those two the
    /// numbers have to do the describing instead.
    var optionsAreNamed: Bool {
        !optionA.hasPrefix("e.g.") && !optionA.hasPrefix("Option ")
    }

    /// One-tap names for a scenario whose sides the app can't name for itself.
    ///
    /// "Getting somewhere" is the first tile and the one decision with no fixed pair of
    /// options — it could be any two of a dozen ways to travel — so its verdict falls
    /// back to describing the winner by its numbers. Offering the usual suspects costs
    /// one tap and turns "the cheaper one" into "the bus".
    var nameSuggestions: [String] = []

    /// Words people might actually type when searching.
    var keywords: [String] = []

    /// Grouped by **how often the decision comes up**, not by topic. Sorting by
    /// topic buries the daily ones among the once-a-decade ones; sorting by
    /// frequency puts the rare ones last by construction.
    enum Family: String, CaseIterable, Identifiable {
        case constant = "Comes up constantly"
        case monthly = "Comes up monthly"
        case worthPayingFor = "Is this worth paying for?"
        case occasional = "Once in a while"
        case timeToMoney = "Turning hours into money"
        case lifeSized = "Life-sized"

        var id: String { rawValue }

        var symbol: String {
            switch self {
            case .constant: return "sun.horizon.fill"
            case .monthly: return "calendar"
            case .worthPayingFor: return "questionmark.circle.fill"
            case .occasional: return "clock.arrow.circlepath"
            case .timeToMoney: return "hourglass.bottomhalf.filled"
            case .lifeSized: return "mountain.2.fill"
            }
        }
    }

    static let fallback = ScenarioTemplate(
        title: "Something else", symbol: "slider.horizontal.3",
        blurb: "Any two options, weighed the same way.",
        family: .occasional, optionA: "Option A", optionB: "Option B",
        directionA: .cost, directionB: .cost, frequency: .once,
        showsSetup: false, setupLabel: "One-off cost to start",
        hint: "What does each one cost you, in money and in time?")

    static let all: [ScenarioKind: ScenarioTemplate] = [

        // MARK: - Comes up constantly

        .fasterVsCheaper: ScenarioTemplate(
            title: "Getting somewhere", symbol: "figure.walk.motion",
            blurb: "Uber, bus, train, walking. Whatever the options are.",
            family: .constant, optionA: "e.g. Uber", optionB: "e.g. the bus",
            directionA: .cost, directionB: .cost, frequency: .once,
            showsSetup: false, setupLabel: "One-off cost to start",
            involvesTravel: true,
            canGoWrong: true,
            hint: "Door to door, including waiting. The wait is part of the journey.",
            nameSuggestions: ["Uber", "Taxi", "Bus", "Train", "Tube", "Drive", "Cycle", "Walk"],
            keywords: ["uber", "taxi", "bus", "train", "walk", "cab", "travel", "journey", "tube"]),

        .paySomeoneElse: ScenarioTemplate(
            title: "Pay someone else", symbol: "hands.and.sparkles.fill",
            blurb: "A cleaner, grocery delivery, laundry, a handyman.",
            family: .constant, optionA: "Pay someone", optionB: "Do it myself",
            directionA: .cost, directionB: .cost, frequency: .weekly,
            showsSetup: false, setupLabel: "One-off cost to start",
            canGoWrong: true,
            isCountable: true,
            showsSetupTime: true, setupTimeLabel: "Finding someone",
            hint: "Count the whole job when you do it yourself — the shopping trip, not just the cooking. And count the finding: the searching, the messaging and the first visit are hours you spend once before any of the saving starts.",
            keywords: ["cleaner", "laundry", "delivery", "handyman", "ironing", "outsource"]),

        .deliverVsCollect: ScenarioTemplate(
            title: "Delivery or collection", symbol: "shippingbox.fill",
            blurb: "Pay the delivery fee, or go and get it.",
            family: .constant, optionA: "Have it delivered", optionB: "Go and collect it",
            directionA: .cost, directionB: .cost, frequency: .once,
            showsSetup: false, setupLabel: "One-off cost to start",
            involvesTravel: true,
            canGoWrong: true,
            hint: "Collection means the journey both ways, plus whatever you buy while you're there.",
            keywords: ["delivery", "collect", "postage", "shipping", "click"]),

        .parkingCloseVsFar: ScenarioTemplate(
            title: "Park close or park cheap", symbol: "parkingsign.circle.fill",
            blurb: "The expensive space by the door, or the free one ten minutes out.",
            family: .constant, optionA: "Park close", optionB: "Park cheap",
            directionA: .cost, directionB: .cost, frequency: .once,
            showsSetup: false, setupLabel: "One-off cost to start",
            involvesTravel: true,
            canGoWrong: true,
            hint: "The walk counts twice — there and back.",
            keywords: ["parking", "car park", "park"]),

        .skipTheQueue: ScenarioTemplate(
            title: "Pay to skip the queue", symbol: "forward.fill",
            blurb: "Fast track, priority boarding, a seat reservation.",
            family: .constant, optionA: "Pay to skip it", optionB: "Queue up",
            directionA: .cost, directionB: .cost, frequency: .once,
            showsSetup: false, setupLabel: "One-off cost to start",
            hint: "Queue time is usually the deadest time there is. Say so below.",
            keywords: ["queue", "fast track", "priority", "boarding", "skip", "line"]),

        .eatOutVsCook: ScenarioTemplate(
            title: "Eat out, takeaway, or cook", symbol: "fork.knife",
            blurb: "The most frequent money, time and mood decision there is.",
            family: .constant, optionA: "Order in or eat out", optionB: "Cook it",
            directionA: .cost, directionB: .cost, frequency: .weekly,
            showsSetup: false, setupLabel: "One-off cost to start",
            involvesOthers: true,
            isCountable: true,
            showsTimesEach: true,
            hint: "Cooking is the shopping, the cooking and the washing up. All of it counts. Then how many times a week each — they are rarely the same number, and two takeaways against five home dinners is the whole shape of it.",
            essentialQuestions: [.health],
            keywords: ["food", "takeaway", "deliveroo", "cook", "dinner", "restaurant", "eat"]),

        .coffeeOutVsHome: ScenarioTemplate(
            title: "Coffee and lunch out", symbol: "cup.and.saucer.fill",
            blurb: "Small, daily, and startling over a year.",
            family: .constant, optionA: "Buy it out", optionB: "Bring it from home",
            directionA: .cost, directionB: .cost, frequency: .daily,
            showsSetup: true, setupLabel: "Kit you'd have to buy",
            isCountable: true,
            hint: "Making it at home takes minutes too — put them in, and the flask or the machine in the one-off field. And if you enjoy the walk, say so.",
            keywords: ["coffee", "lunch", "meal deal", "sandwich", "flat white"]),

        .driveOrTrain: ScenarioTemplate(
            title: "Drive or take the train", symbol: "car.side.fill",
            blurb: "Fuel, parking and tolls against a ticket.",
            family: .constant, optionA: "Drive", optionB: "Take the train",
            directionA: .cost, directionB: .cost, frequency: .once,
            showsSetup: false, setupLabel: "One-off cost to start",
            involvesTravel: true,
            canGoWrong: true,
            hint: "Driving costs more than fuel — add parking and roughly 20p a mile for wear. The train is cheaper to sit on and you can work, but you leave when it leaves.",
            essentialQuestions: [.usableTime, .flexibility],
            keywords: ["drive", "train", "car", "fuel", "petrol", "rail", "tolls"]),

        .inPersonOrRemote: ScenarioTemplate(
            title: "In person or remote", symbol: "video.fill",
            blurb: "Travel time and cost, against actually being there.",
            family: .constant, optionA: "Go in person", optionB: "Join remotely",
            directionA: .cost, directionB: .cost, frequency: .once,
            showsSetup: false, setupLabel: "One-off cost to start",
            involvesTravel: true,
            involvesOthers: true,
            canGoWrong: true,
            hint: "Being in the room is often worth real money. Put that on the feel slider rather than pretending it's zero.",
            essentialQuestions: [.feel],
            keywords: ["remote", "zoom", "meeting", "office", "commute", "conference", "wfh"]),

        // MARK: - Comes up monthly

        .switchProvider: ScenarioTemplate(
            title: "Switch provider", symbol: "arrow.triangle.2.circlepath",
            blurb: "Energy, broadband, phone, insurance. Admin now for a saving later.",
            family: .monthly, optionA: "Switch", optionB: "Stay put",
            directionA: .cost, directionB: .cost, frequency: .monthly,
            showsSetup: true, setupLabel: "One-off cost to switch",
            canGoWrong: true,
            setupTimeLabel: "Hours to switch",
            hint: "Monthly bill for each, then the hours it takes to actually move.",
            keywords: ["switch", "energy", "broadband", "phone", "insurance", "provider", "tariff", "renew"]),

        .subscription: ScenarioTemplate(
            title: "Subscription check", symbol: "repeat.circle.fill",
            blurb: "Is this monthly thing still earning its place?",
            family: .monthly, optionA: "Keep it", optionB: "Cancel it",
            directionA: .cost, directionB: .cost, frequency: .monthly,
            showsSetup: false, setupLabel: "One-off cost to start",
            hint: "There's often no time difference here, so how it feels does the work.",
            isYesNo: true,
            essentialQuestions: [.feel],
            keywords: ["subscription", "netflix", "spotify", "cancel", "membership", "streaming"]),

        .groceries: ScenarioTemplate(
            title: "Delivery or the shop", symbol: "basket.fill",
            blurb: "One delivery a week against however many trips you actually make.",
            family: .monthly, optionA: "Get it delivered", optionB: "Go to the shop",
            directionA: .cost, directionB: .cost, frequency: .weekly,
            showsSetup: true, setupLabel: "Delivery pass a year",
            setupFrequency: .yearly,
            involvesTravel: true,
            canGoWrong: true,
            isCountable: true,
            showsTimesEach: true,
            hint: "Count the trips honestly — delivery is once, the shop is rarely once. Add what you spend in there that you didn't plan to, and say below if wandering the aisles wipes you out.",
            essentialQuestions: [.drain],
            keywords: ["groceries", "shop", "supermarket", "delivery", "food shop", "tesco", "ocado", "shopping"]),

        .bulkBuy: ScenarioTemplate(
            title: "Cheaper shop, further away", symbol: "cart.fill",
            blurb: "A trip across town, or a bulk buy, to shave the weekly shop.",
            family: .monthly, optionA: "Go to the cheaper shop", optionB: "Buy local",
            directionA: .cost, directionB: .cost, frequency: .weekly,
            showsSetup: true, setupLabel: "Membership a year",
            setupFrequency: .yearly,
            involvesTravel: true,
            isCountable: true,
            showsTimesEach: true,
            hint: "Count the travel time both ways, and the extra faff of the bigger trip, then how many trips a week each — one big shop against three local ones is the point. Any membership goes in the yearly field — a warehouse club is often the whole of the saving.",
            keywords: ["shop", "supermarket", "bulk", "costco", "groceries", "aldi"]),

        .fixTheFriction: ScenarioTemplate(
            title: "Fix the daily friction", symbol: "bolt.badge.clock.fill",
            blurb: "The slow laptop, the bad chair, the tap that takes two hands.",
            family: .monthly, optionA: "Fix it", optionB: "Put up with it",
            directionA: .cost, directionB: .cost, frequency: .daily,
            showsSetup: true, setupLabel: "Cost of fixing it",
            isCountable: true,
            setupTimeLabel: "Hours to fix it",
            hint: "Ten minutes a day is sixty hours a year. Put the daily loss on the right.",
            keywords: ["laptop", "slow", "upgrade", "chair", "broken", "annoying", "friction"]),

        // MARK: - Is this worth paying for?

        .gymVsPayg: ScenarioTemplate(
            title: "Membership or pay as you go", symbol: "figure.run",
            blurb: "The gym, the pool, the climbing wall. How often do you really go?",
            family: .worthPayingFor, optionA: "Membership", optionB: "Pay each time",
            directionA: .cost, directionB: .cost, frequency: .monthly,
            showsSetup: true, setupLabel: "Joining fee",
            isCountable: true,
            chargedEachTimeA: false,
            chargedEachTimeB: true,
            showsTimesEach: true,
            setupTimeLabel: "Signing up",
            hint: "Membership monthly, the drop-in price per visit — then how many visits a month. Be honest: the number you actually managed last month, not the plan. What it does for you counts too — on the cost alone the answer is always whichever is cheaper, which is not why anyone joins a gym.",
            essentialQuestions: [.health],
            keywords: ["gym", "membership", "pool", "climbing", "yoga", "class"]),

        .seasonTicket: ScenarioTemplate(
            title: "Season ticket or railcard", symbol: "ticket.fill",
            blurb: "Travelcard, season ticket, railcard. Break-even on how often you go.",
            family: .worthPayingFor, optionA: "Buy the pass", optionB: "Pay per journey",
            directionA: .cost, directionB: .cost, frequency: .monthly,
            showsSetup: true, setupLabel: "Cost of the pass",
            setupFrequency: .yearly,
            canGoWrong: true,
            isCountable: true,
            chargedEachTimeA: false,
            chargedEachTimeB: true,
            startsOnTheOneOff: true,
            showsTimesEach: true,
            hint: "Pass price in the yearly field, then the single fare you'd otherwise pay underneath — one journey, not a month of them — and how many journeys you make in a month. That is the whole sum: the pass is the same price whether you travel twice or forty times, and the fare isn't.",
            keywords: ["season ticket", "railcard", "travelcard", "oyster", "pass", "annual"]),

        .annualVsMonthly: ScenarioTemplate(
            title: "Annual or monthly billing", symbol: "creditcard.fill",
            blurb: "The yearly discount, against being tied in.",
            family: .worthPayingFor, optionA: "Pay yearly", optionB: "Pay monthly",
            directionA: .cost, directionB: .cost, frequency: .monthly,
            showsSetup: true, setupLabel: "Paid yearly, up front",
            setupFrequency: .yearly,
            startsOnTheOneOff: true,
            hint: "The yearly price in the yearly field, the monthly price in the monthly one. The saving is real; so is the chance you stop wanting it in month four.",
            keywords: ["annual", "monthly", "billing", "discount", "yearly", "upfront"]),

        .buyNowVsWait: ScenarioTemplate(
            title: "Buy now or wait", symbol: "clock.arrow.circlepath",
            blurb: "Wait for the sale, or have it now.",
            family: .worthPayingFor, optionA: "Buy it now", optionB: "Wait for the sale",
            directionA: .cost, directionB: .cost, frequency: .once,
            showsSetup: false, setupLabel: "One-off cost to start",
            canGoWrong: true,
            hint: "Waiting isn't free — count the weeks you go without it, and whether the sale is a sure thing.",
            keywords: ["sale", "wait", "black friday", "discount", "buy now", "deal"]),

        .extendedWarranty: ScenarioTemplate(
            title: "Warranty or add-on", symbol: "shield.lefthalf.filled",
            blurb: "Extended warranty, insurance add-on, protection plan.",
            family: .worthPayingFor, optionA: "Buy the cover", optionB: "Go without",
            directionA: .cost, directionB: .cost, frequency: .once,
            showsSetup: false, setupLabel: "One-off cost to start",
            canGoWrong: true,
            hint: "Leave the cover's time at zero, then say below how likely and how bad a failure would be. The maths does the rest.",
            isYesNo: true,
            secondSideIsBlank: true,
            essentialQuestions: [.risk],
            keywords: ["warranty", "cover", "protection", "insurance", "add-on", "guarantee"]),

        .claimVsPay: ScenarioTemplate(
            title: "Claim, or pay it yourself", symbol: "doc.text.fill",
            blurb: "The excess and the premium rise, against the repair bill.",
            family: .worthPayingFor, optionA: "Make a claim", optionB: "Pay it myself",
            directionA: .cost, directionB: .cost, frequency: .yearly,
            showsSetup: true, setupLabel: "Paid now — excess or repair bill",
            horizonMonths: 60,
            canGoWrong: true,
            startsOnTheOneOff: true,
            setupTimeLabel: "Time on the claim",
            hint: "The excess or the repair bill in the one-off field, then what the claim adds to your premium each year underneath. Then set how long you'll be paying it.",
            essentialQuestions: [.risk],
            keywords: ["claim", "insurance", "excess", "premium", "no claims"]),

        .buyOrRent: ScenarioTemplate(
            title: "Buy it or rent it", symbol: "shippingbox.and.arrow.backward.fill",
            blurb: "Tools, a van, a suit, a carpet cleaner. How many times will you use it?",
            family: .worthPayingFor, optionA: "Buy one", optionB: "Rent each time",
            directionA: .cost, directionB: .cost, frequency: .yearly,
            showsSetup: true, setupLabel: "Price to buy",
            horizonMonths: 60,
            canGoWrong: true,
            isCountable: true,
            startsOnTheOneOff: true,
            hint: "Owning also costs storage and upkeep. Renting costs a trip there and back each time.",
            essentialQuestions: [.usage],
            keywords: ["rent", "hire", "buy", "tools", "van", "suit", "borrow"]),

        .buyOutrightVsSubscribe: ScenarioTemplate(
            title: "Buy outright or subscribe", symbol: "infinity",
            blurb: "Pay once and own it, or pay every month for as long as you use it.",
            family: .worthPayingFor, optionA: "Buy it outright", optionB: "Subscribe",
            directionA: .cost, directionB: .cost, frequency: .monthly,
            showsSetup: true, setupLabel: "Price to buy outright",
            horizonMonths: 60,
            startsOnTheOneOff: true,
            hint: "Purchase price in the one-off field, the subscription underneath. Then stretch the horizon — a subscription with no end date is the whole point.",
            keywords: ["subscribe", "buy", "outright", "licence", "saas", "own", "monthly", "forever", "perpetual"]),

        .costPerUse: ScenarioTemplate(
            title: "Is it worth buying?", symbol: "tshirt.fill",
            blurb: "Clothes, kit, gadgets. The price matters far less than the cost per wear.",
            family: .worthPayingFor, optionA: "Buy it", optionB: "Don't",
            directionA: .cost, directionB: .cost, frequency: .weekly,
            showsSetup: true, setupLabel: "Price",
            horizonMonths: 60,
            isCountable: true,
            startsOnTheOneOff: true,
            hint: "Price in the field above, how often you'd use it below, and how long it'd last in \"Counted over\". A £120 coat worn weekly for five years is 46p a wear; worn twice it's £60.",
            isYesNo: true,
            secondSideIsBlank: true,
            essentialQuestions: [.usage],
            keywords: ["clothes", "clothing", "coat", "shoes", "buy", "wear", "cost per wear", "kit", "gadget", "staple"]),

        .paysYouBack: ScenarioTemplate(
            title: "Something that keeps paying", symbol: "arrow.triangle.2.circlepath.circle.fill",
            blurb: "A tool, a machine, an automation. Pay once, and it works while you don't.",
            family: .worthPayingFor, optionA: "Buy it / set it up", optionB: "Carry on as I am",
            directionA: .cost, directionB: .cost, frequency: .weekly,
            showsSetup: true, setupLabel: "Cost to buy or set up",
            horizonMonths: 60,
            involvesEffort: true,
            canGoWrong: true,
            isCountable: true,
            startsOnTheOneOff: true,
            setupTimeLabel: "Hours to set it up",
            hint: "Cost up front on the left, then on the right what carrying on as you are costs you every week — the time it takes, the money it eats. Stretch the horizon: the whole point is that it keeps going without you.",
            keywords: ["automate", "automation", "tool", "machine", "dishwasher", "passive", "invest", "asset", "leverage", "system"]),

        .buyOnceBetterForever: ScenarioTemplate(
            title: "Buy once, better forever", symbol: "moon.stars.fill",
            blurb: "Blackout curtains, floor lamps, a decent mattress. Small money, permanently better days.",
            family: .worthPayingFor, optionA: "Buy it", optionB: "Leave things as they are",
            directionA: .cost, directionB: .cost, frequency: .daily,
            showsSetup: true, setupLabel: "Cost to buy",
            horizonMonths: 120,
            isCountable: true,
            startsOnTheOneOff: true,
            hint: "Cost up front on the left. On the right, what leaving things as they are costs you every day — the minutes, the faff, what it does to your sleep. These look marginal over a year and obvious over ten, so set the horizon honestly.",
            essentialQuestions: [.health],
            keywords: ["curtains", "blackout", "lighting", "lamp", "mattress", "sleep", "bedroom", "comfort", "home", "quality of life"]),

        .payForSpeed: ScenarioTemplate(
            title: "Pay to make it faster", symbol: "hare.fill",
            blurb: "Fast-track passport, express visa, next-day anything.",
            family: .worthPayingFor, optionA: "Pay for the fast one", optionB: "Wait the normal time",
            directionA: .cost, directionB: .cost, frequency: .once,
            showsSetup: false, setupLabel: "One-off cost to start",
            canGoWrong: true,
            hint: "The fee and the form-filling go in the fields — not the waiting, which costs you no hours. Then what happens if it doesn't come in time: paying to skip the queue is nearly always about a date that can't move, and if there isn't one, there's usually no case for the fee.",
            essentialQuestions: [.risk, .feel],
            keywords: ["fast track", "express", "passport", "visa", "next day", "expedite", "urgent"]),

        // MARK: - Once in a while

        .buyRepairDoWithout: ScenarioTemplate(
            title: "Repair or replace", symbol: "wrench.and.screwdriver.fill",
            blurb: "Fix the old one, buy a new one, or manage without.",
            family: .occasional, optionA: "Repair it", optionB: "Replace it",
            directionA: .cost, directionB: .cost, frequency: .yearly,
            showsSetup: true, setupLabel: "Cost today",
            horizonMonths: 60,
            involvesEffort: true,
            canGoWrong: true,
            startsOnTheOneOff: true,
            showsLifespan: true,
            setupTimeLabel: "Waiting in, or researching",
            hint: "What each costs today, and how long each one buys you — with a repair that second question is the whole decision. Hours in the one-off time: waiting in for the repair, researching the replacement. The yearly field is for running costs, if they differ.",
            keywords: ["repair", "replace", "fix", "broken", "mend"]),

        .returnAnItem: ScenarioTemplate(
            title: "Return it, or keep it", symbol: "arrow.uturn.backward",
            blurb: "Is the trip to the post office worth the refund?",
            family: .occasional, optionA: "Return it", optionB: "Keep it",
            directionA: .receive, directionB: .cost, frequency: .once,
            showsSetup: false, setupLabel: "One-off cost to start",
            canGoWrong: true,
            hint: "Packing, printing the label and the queue all count.",
            keywords: ["return", "refund", "post office", "send back"]),

        .experience: ScenarioTemplate(
            title: "Experience vs saving it", symbol: "sparkles",
            blurb: "A gig, a trip, a long lunch with someone you love.",
            family: .occasional, optionA: "Do it", optionB: "Save the money",
            directionA: .cost, directionB: .cost, frequency: .once,
            showsSetup: false, setupLabel: "One-off cost to start",
            involvesOthers: true,
            isAnOccasion: true,
            hint: "Time here means the getting-there and getting-home, not the experience itself — that's what you're paying for, and it belongs on the feel slider. Be honest with that slider. This is the decision where it should win.",
            isYesNo: true,
            essentialQuestions: [.feel, .social],
            keywords: ["gig", "concert", "trip", "holiday", "experience", "tickets", "festival"]),

        .socialEvent: ScenarioTemplate(
            title: "Go out, or stay in", symbol: "figure.socialdance",
            blurb: "The pub, a party, someone's birthday. Rarely about the money.",
            family: .occasional, optionA: "Go", optionB: "Stay in",
            directionA: .cost, directionB: .cost, frequency: .once,
            showsSetup: false, setupLabel: "One-off cost to start",
            involvesOthers: true,
            isAnOccasion: true,
            hint: "Time here means the faff, not the evening: getting ready, getting there, getting home. Don't count the hours at the party — those are the thing you're buying, and they belong on the enjoyment slider instead. Then two separate questions: would you enjoy it, and does it matter to whoever's asking.",
            isYesNo: true,
            essentialQuestions: [.feel, .social],
            keywords: ["pub", "party", "birthday", "social", "friends", "night out", "drinks", "dinner", "wedding", "event"]),

        .upgradeQuality: ScenarioTemplate(
            title: "Buy better, keep longer", symbol: "star.fill",
            blurb: "Pay more once for something that doesn't need replacing.",
            family: .occasional, optionA: "Buy the good one", optionB: "Buy the cheap one",
            directionA: .cost, directionB: .cost, frequency: .yearly,
            showsSetup: true, setupLabel: "Price today",
            horizonMonths: 60,
            canGoWrong: true,
            startsOnTheOneOff: true,
            showsLifespan: true,
            hint: "The price of each and how long each one lasts. That's all — the app works out how many times you'd buy the cheap one, and whether the good one lasts long enough to be worth it. The yearly field is for upkeep, if there is any.",
            keywords: ["quality", "upgrade", "cheap", "lasts", "boots", "durable"]),

        .extraWork: ScenarioTemplate(
            title: "Extra work vs free time", symbol: "banknote.fill",
            blurb: "Overtime, an extra shift, a side project.",
            family: .timeToMoney, optionA: "Take the work", optionB: "Keep the time",
            directionA: .receive, directionB: .cost, frequency: .once,
            showsSetup: false, setupLabel: "One-off cost to start",
            hint: "Use what you'd actually keep after tax, and count the hours you'd be useless afterwards.",
            isYesNo: true,
            keywords: ["overtime", "shift", "side gig", "freelance", "extra work", "moonlight"]),

        .unplannedWork: ScenarioTemplate(
            title: "Chase the new idea, or not", symbol: "arrow.branch",
            blurb: "It wasn't the plan for today. It rarely stays an hour.",
            family: .timeToMoney, optionA: "Follow the idea", optionB: "Stick to the plan",
            directionA: .cost, directionB: .cost, frequency: .once,
            showsSetup: false, setupLabel: "One-off cost to start",
            involvesEffort: true,
            hint: "Estimate the hours, then double them — this is the decision people misjudge most. Say what the time comes out of: work you've pushed back doesn't disappear, it comes back later with less room. And be honest about whether you'd still do it next week.",
            isYesNo: true,
            essentialQuestions: [.displaces],
            keywords: ["idea", "project", "scope", "tangent", "side project", "distraction", "plan", "unplanned", "rabbit hole"]),

        .squeezeItIn: ScenarioTemplate(
            title: "Squeeze it in, or leave it", symbol: "bed.double.circle.fill",
            blurb: "The gym at eleven at night. The jobs before bed. Now, or tomorrow.",
            family: .occasional, optionA: "Do it now", optionB: "Leave it and rest",
            directionA: .cost, directionB: .cost, frequency: .once,
            showsSetup: false, setupLabel: "One-off cost to start",
            involvesEffort: true,
            hint: "Say honestly whether it'll cost you sleep, and whether you'd genuinely do it tomorrow instead. If you would, tonight buys you very little — and sleep is not something to be squeezed around.",
            isYesNo: true,
            // Feel first because it unlocks the next one: "would you do it tomorrow"
            // is only a question once there is something worth postponing.
            essentialQuestions: [.feel, .canItWait, .drain],
            keywords: ["gym", "sleep", "late", "tired", "squeeze", "tonight", "bed", "rest", "recovery", "tomorrow"]),

        // The mirror of the subscription check, for money coming in. Everything else
        // here is about taking work on; nothing was about letting go of something you
        // already do — which is the harder call, because the money is already yours
        // and the hours have stopped being visible.
        .dropAnIncome: ScenarioTemplate(
            title: "Is this income worth the hours?", symbol: "briefcase.fill",
            blurb: "A side gig, a client, a rental, a second job. What it pays, against what it takes.",
            family: .timeToMoney, optionA: "Keep it", optionB: "Drop it",
            directionA: .receive, directionB: .cost, frequency: .monthly,
            showsSetup: false, setupLabel: "One-off cost to start",
            involvesEffort: true,
            hint: "What it pays a month, and the hours it really takes a month — the admin, the chasing and the invoicing as well as the work. Then say honestly whether it wipes you out, because the hours it costs you afterwards are the ones nobody counts.",
            isYesNo: true,
            essentialQuestions: [.drain],
            keywords: ["side hustle", "side gig", "freelance", "client", "second job", "quit",
                       "drop", "stop", "income", "tutoring", "rental", "moonlight", "overtime",
                       "worth it", "give up"]),

        .sellStuff: ScenarioTemplate(
            title: "Turn stuff into money", symbol: "tag.fill",
            blurb: "Photographing, listing, posting, meeting buyers.",
            family: .timeToMoney, optionA: "Sell it", optionB: "Keep or donate it",
            directionA: .receive, directionB: .cost, frequency: .once,
            showsSetup: false, setupLabel: "One-off cost to start",
            involvesEffort: true,
            canGoWrong: true,
            hint: "The listing is ten minutes. The messages, the packing and the post office are not.",
            keywords: ["sell", "ebay", "vinted", "marketplace", "declutter", "gumtree"]),

        .shopAround: ScenarioTemplate(
            title: "Shop around", symbol: "magnifyingglass",
            blurb: "Is the hunt for a better price worth the hours?",
            family: .timeToMoney, optionA: "Spend time hunting", optionB: "Just buy it now",
            directionA: .cost, directionB: .cost, frequency: .once,
            showsSetup: false, setupLabel: "One-off cost to start",
            involvesEffort: true,
            hint: "Put the price you'd realistically end up paying on each side.",
            keywords: ["compare", "shop around", "research", "cheaper", "price"]),

        .diyVsHire: ScenarioTemplate(
            title: "DIY vs hire someone", symbol: "hammer.fill",
            blurb: "Painting, flat-packs, the leaking tap, the website.",
            family: .timeToMoney, optionA: "Do it myself", optionB: "Hire someone",
            directionA: .cost, directionB: .cost, frequency: .once,
            showsSetup: false, setupLabel: "One-off cost to start",
            involvesEffort: true,
            canGoWrong: true,
            hint: "Your estimate of the hours is probably low. It usually is. Then say what you'd come away able to do — a skill you'll use again is worth real money, and one you won't is just a longer way of being busy.",
            essentialQuestions: [.growth],
            keywords: ["diy", "hire", "builder", "plumber", "decorator", "paint", "flat pack"]),

        .secondHandVsNew: ScenarioTemplate(
            title: "Second-hand or new", symbol: "arrow.3.trianglepath",
            blurb: "The saving is real. So are the evenings spent hunting.",
            family: .occasional, optionA: "Find one second-hand", optionB: "Buy it new",
            directionA: .cost, directionB: .cost, frequency: .yearly,
            showsSetup: true, setupLabel: "Price",
            horizonMonths: 60,
            canGoWrong: true,
            startsOnTheOneOff: true,
            showsLifespan: true,
            setupTimeLabel: "Hunting for one",
            hint: "Price on each side, then how long each one lasts — a used one with two years left isn't cheaper than a new one with eight. Put the searching, the messaging and the trip to collect it in the one-off time: you do all of it again every time you replace it.",
            keywords: ["second hand", "used", "new", "refurbished", "preowned"]),

        .sellIndividuallyVsBulk: ScenarioTemplate(
            title: "Sell one by one, or the lot", symbol: "shippingbox.fill",
            blurb: "More money for far more evenings, against one transaction and done.",
            family: .timeToMoney, optionA: "List them individually", optionB: "Sell the lot in one go",
            directionA: .receive, directionB: .receive, frequency: .once,
            showsSetup: false, setupLabel: "One-off cost to start",
            involvesEffort: true,
            canGoWrong: true,
            isCountable: true,
            showsTimesEach: true,
            hint: "Per item it's photos, a listing, the messages, the packing and the post office — enter one item's worth, then say how many. The other side is one transaction and done, so that side is one.",
            keywords: ["sell", "bulk", "job lot", "individually", "vinted", "ebay", "clothes", "declutter", "car boot"]),

        .payForAdmin: ScenarioTemplate(
            title: "Pay someone to do the admin", symbol: "doc.on.clipboard.fill",
            blurb: "Tax return, forms, applications, chasing a refund.",
            family: .timeToMoney, optionA: "Pay someone", optionB: "Do it myself",
            directionA: .cost, directionB: .cost, frequency: .yearly,
            showsSetup: false, setupLabel: "One-off cost to start",
            involvesEffort: true,
            isCountable: true,
            hint: "Count the dread as well as the hours — admin you keep putting off costs more than the clock says.",
            keywords: ["accountant", "tax return", "admin", "forms", "paperwork", "self assessment"]),

        .dayOffForAdmin: ScenarioTemplate(
            title: "Take a day off to clear it", symbol: "calendar.badge.clock",
            blurb: "Spend a day's leave doing life admin, or grind through it in the evenings.",
            family: .timeToMoney, optionA: "Take the day", optionB: "Do it in the evenings",
            directionA: .cost, directionB: .cost, frequency: .once,
            showsSetup: false, setupLabel: "One-off cost to start",
            involvesEffort: true,
            hint: "Annual leave is currency too. Evening hours are worth less than they look — you're tired.",
            keywords: ["day off", "annual leave", "holiday", "admin day", "time off"]),

        .babysitterTax: ScenarioTemplate(
            title: "A night out, all in", symbol: "figure.2.and.child.holdinghands",
            blurb: "A £40 evening is a £110 evening once childcare is in it.",
            family: .occasional, optionA: "Go out", optionB: "Stay in",
            directionA: .cost, directionB: .cost, frequency: .once,
            showsSetup: false, setupLabel: "One-off cost to start",
            involvesOthers: true,
            canGoWrong: true,
            isAnOccasion: true,
            hint: "Put the whole cost in — sitter, travel, the lot. Then be generous on the feel slider, because you should be — and remember it isn't only your evening.",
            isYesNo: true,
            essentialQuestions: [.feel, .social],
            keywords: ["babysitter", "childcare", "night out", "evening", "sitter"]),

        .learnItOnce: ScenarioTemplate(
            title: "Learn it once, save forever", symbol: "brain.head.profile",
            blurb: "Hours now to learn something that saves you time every week after.",
            family: .timeToMoney, optionA: "Learn to do it", optionB: "Keep doing it the slow way",
            directionA: .cost, directionB: .cost, frequency: .weekly,
            showsSetup: true, setupLabel: "Cost of learning it",
            horizonMonths: 60,
            involvesEffort: true,
            isCountable: true,
            startsOnTheOneOff: true,
            setupTimeLabel: "Hours to learn it",
            hint: "Learning goes in the one-off field, the weekly time saved underneath. Look years ahead — this is the one that compounds.",
            essentialQuestions: [.growth],
            keywords: ["learn", "skill", "shortcut", "automate", "training", "course"]),

        // MARK: - Life-sized

        .commuteVsRent: ScenarioTemplate(
            title: "Commute vs rent", symbol: "house.fill",
            blurb: "Cheaper further out, or pay more to live close in.",
            family: .lifeSized, optionA: "Cheaper, further out", optionB: "Dearer, closer in",
            directionA: .cost, directionB: .cost, frequency: .daily,
            showsSetup: true, setupLabel: "Rent a month", setupFrequency: .monthly,
            involvesTravel: true,
            canGoWrong: true,
            hint: "Daily travel cost and door-to-door time at the top, then the monthly rent underneath.",
            keywords: ["rent", "commute", "move", "flat", "house", "zone"]),

        .fourDayWeek: ScenarioTemplate(
            title: "Drop a day a week", symbol: "calendar.badge.minus",
            blurb: "Four days instead of five. The purest version of this trade.",
            family: .lifeSized, optionA: "Drop the day", optionB: "Stay full time",
            directionA: .receive, directionB: .receive, frequency: .monthly,
            showsSetup: false, setupLabel: "One-off cost to start",
            hint: "Monthly take-home on each side, and the hours you'd give back. Look a year or more ahead.",
            keywords: ["four day week", "part time", "drop hours", "compressed", "reduce hours"]),

        .salaryVsCommute: ScenarioTemplate(
            title: "More money, longer commute", symbol: "tram.fill",
            blurb: "A better-paid job that's further away.",
            family: .lifeSized, optionA: "Take the job", optionB: "Stay where I am",
            directionA: .receive, directionB: .receive, frequency: .daily,
            showsSetup: true, setupLabel: "Take-home a month", setupFrequency: .monthly,
            involvesTravel: true,
            canGoWrong: true,
            hint: "Daily travel cost and door-to-door time at the top, then monthly take-home underneath.",
            keywords: ["job", "salary", "offer", "commute", "new job", "promotion"]),

        .childcareVsHours: ScenarioTemplate(
            title: "Childcare vs dropping hours", symbol: "figure.and.child.holdinghands",
            blurb: "Nursery fees against a parent's hours. Often the biggest sum in a household.",
            family: .lifeSized, optionA: "Pay for childcare, keep working", optionB: "Drop hours instead",
            directionA: .cost, directionB: .cost, frequency: .monthly,
            showsSetup: false, setupLabel: "One-off cost to start",
            involvesOthers: true,
            canGoWrong: true,
            hint: "Fees minus any free hours or tax-free childcare, against the take-home you'd lose.",
            keywords: ["childcare", "nursery", "children", "maternity", "kids", "parental"]),

        .trainingForPay: ScenarioTemplate(
            title: "Train now, earn later", symbol: "graduationcap.fill",
            blurb: "A course or qualification that should pay for itself.",
            family: .lifeSized, optionA: "Do the course", optionB: "Don't",
            directionA: .receive, directionB: .cost, frequency: .monthly,
            showsSetup: true, setupLabel: "Course fees",
            horizonMonths: 60,
            setupDirectionA: .cost,
            involvesEffort: true,
            canGoWrong: true,
            startsOnTheOneOff: true,
            setupTimeLabel: "Study hours",
            hint: "Fees and study hours up front, then the monthly pay rise underneath. Look several years ahead — and the capability counts as well as the money, which is often the better half of it.",
            isYesNo: true,
            secondSideIsBlank: true,
            essentialQuestions: [.growth],
            keywords: ["course", "training", "qualification", "degree", "certification", "study"]),

        .carOwnership: ScenarioTemplate(
            title: "Own a car, or don't", symbol: "car.fill",
            blurb: "Insurance, tax, MOT, depreciation — against taxis and car clubs.",
            family: .lifeSized, optionA: "Keep the car", optionB: "Taxis and car club",
            directionA: .cost, directionB: .cost, frequency: .monthly,
            showsSetup: true, setupLabel: "Price, or sale proceeds",
            horizonMonths: 60,
            setupDirectionB: .receive,
            canGoWrong: true,
            isCountable: true,
            chargedEachTimeA: false,
            chargedEachTimeB: false,
            setupTimeLabel: "Selling or buying it",
            hint: "Everything the car costs per month, including the bit nobody counts: depreciation — and the taxis and car club as a month's worth too, not per trip. Then the lump sum: what selling it would bring, on the right — or the price of buying one, if that's the way round you're asking.",
            keywords: ["car", "sell car", "zipcar", "car club", "insurance", "mot", "depreciation"]),

        .takeALodger: ScenarioTemplate(
            title: "Take a lodger", symbol: "bed.double.fill",
            blurb: "Rent for privacy. The feel slider matters more than the money here.",
            family: .lifeSized, optionA: "Take a lodger", optionB: "Keep the place to myself",
            directionA: .receive, directionB: .cost, frequency: .monthly,
            showsSetup: true, setupLabel: "Doing up the room",
            setupDirectionA: .cost,
            involvesOthers: true,
            canGoWrong: true,
            setupTimeLabel: "Finding a lodger",
            hint: "Rent received, plus the hours of extra tidying, and what the room costs to get ready in the one-off field — that's what the rent has to pay back first. Then be honest about how it'd feel.",
            isYesNo: true,
            essentialQuestions: [.feel],
            keywords: ["lodger", "flatmate", "housemate", "spare room", "rent out"]),

        .custom: fallback
    ]

    // MARK: - Finding one without scrolling

    static func scenarios(in family: Family) -> [ScenarioKind] {
        ScenarioKind.allCases.filter { $0 != .custom && $0.template.family == family }
    }

    /// Free-text search across titles, blurbs and the words people actually type.
    /// At forty-odd presets this beats any taxonomy.
    static func search(_ query: String) -> [ScenarioKind] {
        // Word by word rather than as one string. "gym membership" and "membership
        // gym" are the same request, and matching the whole query as a run of
        // characters answers only the first — which is a coin toss on a box whose
        // own placeholder invites two words.
        let terms = SearchMatch.terms(query)
        guard !terms.isEmpty else { return [] }

        return ScenarioKind.allCases
            .filter { $0 != .custom }
            .compactMap { kind -> (ScenarioKind, Int, Int)? in
                var worst = 0
                var total = 0
                for term in terms {
                    // Every word typed has to land somewhere. A scenario that answers
                    // half the query is not the scenario.
                    guard let tier = tier(of: term, in: kind.template) else { return nil }
                    worst = max(worst, tier)
                    total += tier
                }
                return (kind, worst, total)
            }
            // Ranked by the *weakest* word's match, because that is how good the
            // answer actually is: a scenario whose title starts with one of your
            // words but that only mentions the other deep in its blurb is a worse
            // answer than one that has both in its keywords.
            .sorted { ($0.1, $0.2) < ($1.1, $1.2) }
            .map(\.0)
    }

    /// How well one typed word matches a scenario, lowest being best. Nil when it
    /// does not match at all.
    private static func tier(of term: String, in t: ScenarioTemplate) -> Int? {
        let title = SearchMatch.fold(t.title)
        let titleWords = title.split(separator: " ").map(String.init)
        let keywords = t.keywords.map(SearchMatch.fold)

        if titleWords.contains(where: { $0.hasPrefix(term) }) { return 0 }
        if keywords.contains(where: { $0.hasPrefix(term) }) { return 1 }
        if title.contains(term) { return 2 }
        if keywords.contains(where: { $0.contains(term) }) { return 3 }
        if SearchMatch.fold(t.blurb).contains(term) { return 4 }
        return nil
    }
}
