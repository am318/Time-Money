# Design notes

The reasoning behind Time / Money: why the rate is built the way it is, which
mistakes the model was caught making and how they were fixed, and the judgement calls
that are still open. The [README](../README.md) is the short version; this is the long
one, and it is written as a log of decisions, so some paragraphs describe a bug that
has since been fixed rather than how the code works today.

Everything is checked against `TimeMoneyTests/` where it can be. The sweep figures
quoted in the audit (tens of thousands of inputs) came from larger one-off runs; the
same properties are asserted over a fixed grid in `ScenarioSweepTests`, where the
average comes out at 1.6 follow-up questions. Numbers quoted below
come from the default profile (£2,400 take-home, £900 rent, £350 bills, £300 saved, a
37.5-hour week and 5 hours of commuting), which works out at £6.86 an hour.

---

## The idea

Everything reduces to one number: **what an hour of your life is worth in pounds,
right now, given your situation.** Every decision then becomes

```
true cost =   money + what that money would have become
            + (time × your rate)
            − (how it feels + what it means to others
               + what it does for you + what you learn)
            + what it risks
```

Time is adjusted for whether you can use it, whether it wrecks you, whether it costs
you sleep, how many people spend it, and what it displaces. The benefits are adjusted
for how likely they are, how rare the chance is, and whether you'd get them anyway
tomorrow.

and the lower total wins.

### Where the rate comes from

| Step | What it is |
|---|---|
| Earned rate | Take-home ÷ paid hours |
| Effective earned rate | Take-home ÷ *every* hour work takes, commute included |
| Leisure rate | Discretionary money ÷ genuinely free hours |
| Blend | 35% effective earned + 65% leisure |
| Convertibility | Salaried leans on the blend; freelancers lean on their billing rate |
| Scarcity | Time-poor ×1.4, balanced ×1.0, money-poor ×0.7 |
| This week | Busier than usual ×1.25, quieter ×0.8 — expires after seven days |
| Deadline pressure | Short of something specific and dated? Up to ×0.6 |

Income is entered as take-home by default: no tax maths at all, just the figure that
arrives, from wherever it comes from. Entering a gross salary instead switches on a
2025/26 PAYE estimate.

Discretionary = take-home − rent − bills − savings target.
Free hours = 168 − sleep − work − commute − life admin.

The leisure rate is the honest one: buying back an hour costs money you'd
otherwise have spent *enjoying* an hour. The blend exists because most people's
instinct about an hour sits between what work pays and what their spare money buys.

Every intermediate value is shown in the app. A rate you don't believe is a rate
you won't act on — and you can overrule it outright.

### The output that matters

Not the verdict, the **tipping point**:

> Uber is worth it only if an hour of your time is worth more than £26.56.
> Yours is £6.86, so the bus wins.

That survives a wrong rate. You can judge whether £26.56 is silly for you even if
the model got you to £6.86 instead of £13.

---

## Things most calculators of this kind get wrong

**Dead time isn't the same as usable time.** A 55-minute bus you can read on costs
you 11 effective minutes; a 20-minute taxi costs 20. Per option: none / some / most,
scaling the time cost ×1.0 / ×0.5 / ×0.2.

**Scarcity changes what something is worth, never what it costs.** A once-in-a-decade
gig isn't cheaper — it's worth more. So it multiplies enjoyment only, up to ×2.5,
and it's only ever asked about once something already feels good.

**Repeated pleasures fade.** A weekly treat isn't fifty-two times as good as one
treat, so enjoyment is counted with diminishing returns (`n^0.6`), not multiplied out.

**Reliability is usually the real reason people pay more.** Expected cost =
how often it goes wrong × what a bad outcome costs, where the stakes belong to the
situation and the reliability belongs to the option.

**Time estimates are optimistic.** Rather than asking how confident you are — everyone
says "quite" — the app pushes the numbers around and reports what actually breaks:
*"If both take twice as long as you think, the answer flips."*

**Cost per use decides purchases; the price doesn't.** A £120 coat worn weekly for five
years is 46p a wear. The same coat bought on a whim is £1.85, and a £180 outfit worn twice
is £90. So the app asks how sure you are you'll use it, and trims the uses rather than the
price — because that's the difference between a staple and a mistake. Strictly the uses: a
direct debit doesn't ask whether you opened the app, so doubt raises what each use costs and
never discounts the bill. Trimming the bill too made a subscription *cheaper* the less you
expected to use it, which is precisely backwards.

**How far out you count is a decision, not a default.** One side paid once against one side
paid every month is settled almost entirely by the horizon, and a year is the single window
in which a perpetual licence cannot win: £210 outright loses to £8.99 a month over twelve
months and beats it comfortably over five years. So the horizon is set per scenario — five
years for anything bought to be kept, ten for the things that quietly improve every day —
and it's a control on the decision itself rather than a constant in the engine.

**The two halves of an option can point opposite ways.** Course fees leave you once and
the pay rise they buy arrives every month for years; a joining fee is paid on the day and
the membership every month after. Signing both halves from one switch makes those decisions
unsayable — £3,000 out against £200 a month back came out as £15,916 whichever way you set
it, and the verdict turned on a toggle that shouldn't have touched it. The one-off leg now
carries its own direction, and defaults to following the other one.

**How long a thing lasts belongs to the thing, not to the decision.** Boots that last ten
years against boots that last two is the whole of "buy better, keep longer", and no single
frequency can hold two different ones — the app used to ask you to convert "£60 every couple
of years" into a yearly replacement cost before you could type it, which is the arithmetic it
exists to do. Lifespan is now a property of each option, and the number of times you buy the
cheap one is worked out from it: three pairs over five years, bought at the start, at two
years and at four. Rounded up, because you replace a thing when it dies rather than buying
four fifths of a new one.

**Letting go of an income is a different decision from taking one on.** Every other
scenario here is about acquiring work; none was about stopping something you already do,
which is the harder call — the money is already yours and the hours have stopped being
visible. £300 a month for twenty-six hours implies £11.54 an hour, and the honest answer
is to keep it while your own hour is worth less than that. Saying whether it wipes you out
moves that line a long way: the same gig, if it costs you sleep, breaks even at £4.70.

And where money is coming in, the app no longer reaches for the vocabulary of cost. Netting
thirty pounds more is not costing less, so an option is "better-paid" rather than "cheaper"
whenever either side is income — calling a side job "the cheaper one" is the sort of sentence
that makes someone stop believing the rest of them.

**A one-off with nowhere to go gets charged every period.** Wherever the money field
recurs and no separate one-off field is offered, anything genuinely paid once has to be
typed into the recurring box — and a £100 membership becomes £5,276 a year at weekly, or
£37,069 at daily. Five scenarios were missing the field the decision turns on: the flask
for bringing coffee from home, the warehouse-club membership, the delivery pass, the lump
sum from selling the car, and the cost of doing up the room before a lodger can pay you
back for it. Adding fields everywhere would be worse than the bug, so the test is whether
the one-off is the thing the answer hangs on.

**Money doesn't sit still.** A pound spent is a pound that would have grown. Modest by
default (2% real), and much larger if you'd have put it somewhere with a bonus — a Lifetime
ISA's 25% makes anything marginal considerably dearer. Everyday decisions shift by pennies;
a £200 impulse shifts by £52.

**Learning only counts when it's taking you somewhere.** A capability you keep is worth more
than an afternoon you enjoyed — but getting good at something you don't need is a longer way
of being busy. Marked as a detour, it scores nothing, and the app will tell you to pay
someone. It also flags when the winning option is winning on hours rather than sense:
*"On money alone you'd be working for £3.10/hr here."*

**The two sides often don't happen at the same rate.** One grocery delivery a week against
three trips to the shop. Comparing them one-for-one flatters whichever one you do more often,
which is usually the one you're trying to get away from — and it flips the answer.

**Deciding is itself tiring.** Anything marked as wiping you out costs a flat ten minutes
each time on top of the clock, so many-small-things pays that over and over where
one-big-thing pays it once.

**Repetition is where the money hides.** £2 a day is £730 a year; 20 minutes a day
is 120 hours. Any decision can be marked as recurring.

**Health is not the same question as enjoyment, and it behaves differently.** The walk
you don't especially enjoy is still good for you; the third takeaway this week is
enjoyable and isn't. And where pleasure fades with repetition, health accumulates —
so enjoyment is damped across occurrences and health is counted in full every time.
One healthy choice is worth about £2.50 and barely registers. Three hundred of them
are worth most of a thousand pounds, and decide the answer.

**A break is not time spent.** A twenty-minute walk in the middle of the afternoon pays
for itself in the quality of the hours after it, so restorative time is charged at
nothing. Without this the app confidently tells you to skip the walk and push on —
and then tells you more confidently the more often you'd do it.

**"When does it pay for itself?" is usually the real question.** For anything bought once
that then keeps giving — curtains, a dishwasher, an automation — the verdict at whatever
horizon you happened to pick is nearly meaningless. The payback period isn't: a dishwasher
at three months, a day spent automating something at two. It counts hours invested as well
as money, because automating something costs a day and no money at all.

**Being ahead is a reason to loosen up.** Everything else in the app is downside pressure —
short of a goal, busy week, money committed. Saying you're ahead of where you need to be makes
enjoyment count for 30% more. It only ever applies when there's genuinely slack: feeling ahead
at work while the rent is a stretch is not a licence to spend, and the app won't pretend it is.

**A decision has consequences for the next one.** Recording what you actually chose commits
that money for thirty days, which comes off what you have spare and tightens everything that
follows. £700 committed drops the rate from £6.86 to £4.97. Selling something puts money back.

**A night out is not a spreadsheet, and the app shouldn't pretend it is.** Three things
come apart that usually get mashed together: whether *you'd* enjoy it, how likely that
is (a party is a gamble in a way a coat isn't), and what it means to *them*. A £45 night
you'd mildly prefer to staying in loses. The same night, when they'd really want you
there, wins. And time here means the faff — getting ready, getting there — not the
evening itself, because the evening is the thing you're buying.

**Things that can wait usually should.** The gym at eleven at night isn't a choice
between training and not training; it's training tonight against training tomorrow, and
tomorrow costs no sleep. Anything you'd genuinely do tomorrow keeps only a fifth of its
value for being squeezed in tonight — and sleep is counted at two and a half times,
deliberately, because it isn't ordinary tiredness.

**Hours come out of something.** An idea you wanted to test turns into a day, and the day
comes out of work you'd already committed to — which doesn't vanish, it arrives later with
less room. Six hours against a deadline are counted as nearly eleven. Follow the idea only
wins when the time was genuinely free *and* it's now or never.

**A soft cooldown.** Saying you'll spend three hours painting means the app quietly
suggests doing that before deciding anything else. A note, never a block — deciding is
easier than doing, and an app that makes deciding frictionless while three commitments sit
unstarted is helping with the wrong problem.

**Two kinds of time pressure.** The chronic kind is already in the numbers: fewer free
hours means a higher rate. The acute kind — the week everything lands at once — is one
tap on the home screen, and unsets itself after seven days so it can never go stale.

---

## When it barely matters, just answer

Saying "too close to call" hands the decision straight back, which is the one thing the
app exists not to do. So when the modelled difference falls inside the noise band, it
falls back on the plainest facts instead:

1. **Cheaper**, if one costs less real money. A sum of money is a fact; a duration is an
   estimate, and estimates are what tend to be wrong — so money goes first.
2. **Quicker**, if the money is level too.
3. Only if *nothing at all* separates them does it say **"Genuinely either"**.

And when the two options are near enough the same thing — under a pound and under ten
minutes apart — it skips the follow-up questions entirely and answers immediately.
Interrogating someone about a choice that barely matters is exactly the friction this is
meant to remove.

There's a distinction worth keeping, though. *Similar* is not the same as *balanced*.
Cheap-and-slow against dear-and-quick can come out dead level while still being a real
trade-off worth a question or two, so that one still gets asked about — it just gets an
answer rather than a shrug, along with the tipping point that explains why it's level.

## Asking as little as possible

One rule: **ask a question only if its answer could change the verdict.**

Each candidate question is re-run at both ends of its plausible range. If the winner
never moves, the question is never put. A £40 gap over ten minutes doesn't need a
feel slider; a £2 gap does.

- **Screen one, always:** four numbers, keypad already up.
- **Then at most three follow-ups**, ranked by whether they flip the answer and by
  how far they move the margin.
- **"Good enough, show me"** on every screen.

The answer is then just the answer. Everything explaining it lives behind *Why?*

Naming is optional throughout. If you don't name an option, the app describes it by
what you actually typed — *"£2.50, 55 min"* — so history still means something in
a month's time.

---

## Reviewing

The rate is the weakest number in the app, and nothing else corrects it. So:

- what you **actually chose** is recorded, including when you overrode the app —
  behaviour beats opinion
- decisions surface a day later for a three-tap look back
- each reviewed decision is attributed to **the term that decided it**, so a run of
  regrets about enjoyment-led calls adjusts the enjoyment anchor rather than everything
  at once

The adjustment is deliberately timid. A raw lean is shrunk towards no change by how
little evidence there is: `1 + 0.35 × tilt × n/(n+12)`. Ten reviews leaning three-to-one
move an anchor by about 6%; thirty leaning heavily move it by 20%, and nothing moves it
further than 35% however lopsided the record.

**An even split returns exactly 1.0 at any sample size, and "can't tell" is excluded
entirely** — it isn't weak evidence for the status quo, it's no evidence, and it's
reported back as *"the 8 you couldn't call either way count for nothing"*. If saying
you don't know quietly nudged something, people would stop saying it.

Offered, never applied. Hindsight is a generous editor and ten is a small sample.

---

## Taking the week's shape from Attention (optional)

Everything above rests on one soft number: how many hours a week are genuinely
yours. It was a subtraction — 168 less sleep, work, commute and chores — and a
subtraction is a guess about a typical week rather than a fact about this one.

Attention, a separate time-tracking app, already measures it, and this app can read
its exported backup file as an optional integration. That backup carries a per-day
digest of what was booked, what was worked and what was free, and Settings →
Attention turns that into the app's own figures. One switch, not a field-by-field
import, because the figures only make sense together: measured evenings against
self-reported sleep would count some hours twice and lose others entirely.

What changes while it's on:

| Was | Becomes |
|---|---|
| Free hours, by subtraction | Free evenings measured against what was actually booked |
| Sleep, as typed in | The stated bedtime and wake time |
| A busy-week setting you remember to set | The next seven days against your own normal |
| Paid hours, as contracted | The working week your timer actually recorded, in conventional hours |
| "Will it wipe you out?", asked | Answered where the thing would run past your wind-down |
| Durations as typed | Setup time corrected by how your own small jobs have actually run |
| Usable time as claimed | Floored by how much of a free working hour really becomes work |

The effect is not small. On a diary with heavily booked evenings it can halve the
free-hours figure and double the rate, which is the point: a rate built on hours
you don't actually have is the single most flattering error this kind of app can
make.

### The working week, in the units people speak in

A contract is a fiction for anyone who doesn't clock in. `paidHoursPerWeek` was
the only thing deciding what an hour of work costs, and for research work — or
anything where the day isn't bounded by a building — 37.5 is a number off a
form rather than a fact about a life.

Attention already measures the honest version, and exports the conversion:

    conventional = deep × r + meetings

`r` is how many hours of working day one hour of deep work costs — measured by
Attention's `EngagedSpan` from the first timer start to the last stop of each
day, median over a fortnight or more of days that qualify. Timed meetings are
added at face value and never scaled. That
figure now drives `effectiveEarnedRate` — what an hour given to work yields, and
what a pound costs in hours of it. **The nominal rate is deliberately left on the
contract**: that one answers "what does an employer pay for a contracted hour",
which no measurement should move.

Three things had to be got right for it to be safe:

- **Overspill is no longer added on top.** Evening and weekend work is already
  inside the timed minutes the conversion is built from, so adding
  `overspillHoursPerWeek` again counted those hours nearly twice — once converted
  and once raw. It keeps its other job untouched, coming off free time, where it
  answers a different question: about the evening it ate, not the wage it earned.
- **Entered work is left out of the total.** Only timed work counts, as
  everywhere else here. But that makes a forgotten timer look like a light week,
  and a light week quietly *raises* the rate — the one direction a measurement
  failure must never push. So untimed days became the refusal instead: past a
  fifth of working days with work recorded and no timer, nothing is reported.
  (Attention's own sufficiency test — fourteen measurable days — runs on the
  session marks, which the digest does not carry, so it cannot be re-checked
  here. It has already been applied to the multiplier before this app sees it.)
- **The scatter is respected, now that it is exported.** A multiplier of two
  measured from days that all ran close to two is a different object from the
  same two measured from days running one to four, and only the first is worth
  pricing an hour against. The `workSpan` block carries the dispersion that makes
  that computable here.

  It is a **ramp, not a cliff**. Attention withholds its own conversion past a
  spread of 0.35, which is the right call for a screen — a row either says
  something or it doesn't. A rate is a number, and a threshold in the middle of
  one means two exports a day apart can move the price of an hour by a tenth with
  nothing in the diary to explain it. So the measured week is believed whole below
  a spread of 0.20, not at all above 0.35, and blended linearly towards the typed
  figure in between. Both endpoints are Attention's: 0.35 is where it stops, and
  0.20 is what it assumes of a personal figure it has no distribution for, so a
  measurement tighter than that is better than the assumption it replaces. This
  app supplies only the shape between them, and the shape is a straight line
  because anything cleverer would assert something about the distribution of
  diaries that nobody has measured.

  A file written before the block existed carries no scatter and is believed whole
  on the older evidence — the alternative is that upgrading this app silently
  moves everybody's rate for failing a check their export cannot answer.
- **Attention's own refusals are adopted whole.** Over five strict hours a day
  it stops converting, on the grounds that the strict figure says more than any
  multiple of it. Under a ratio of 1.15 it stops too, from the other end: a deep
  hour that costs almost nothing beyond itself leaves nothing for a conversion to
  add, and multiplying by something indistinguishable from one returns the strict
  figure with false precision attached. With nothing accepted there is no
  multiplier, and the 1.5 anchor is deliberately not borrowed — Attention now
  describes it as a low placeholder to be phrased as a floor, which is an even
  worse thing to hand to a rate than it was when it was called an estimate.

Each refusal is carried and said out loud rather than silently falling back,
because "we can't measure this" and "you work a normal week" are different
answers.

**It is a small dial, and worth knowing that in advance.** Once the link is on,
the rate is about five times more sensitive to measured free evenings than to
hours worked — a third off the working week moves it 6%, the same off free
evenings moves it 24%. The earned rate only carries 35% weight, and the leisure
rate has already grown because measured evenings are scarce. Where it genuinely
shows is "this costs you 5.4 hours of work", which swings a quarter across the
same range and is shown to the user directly.

**The direction depends entirely on the multiplier, and the multiplier changed.**
Worth recording, because the same code gave opposite answers a fortnight apart.

When `r` was a residual in `1.15...1.5`, the measured week came in *under* the
typed one — on a test export, 28 hours against 37.5 — which *raised* the rate,
the opposite of the intuition that asks for the feature. Now that `r` is a
measured span and lands nearer two, the same export gives 42 hours and the rate
falls instead. A pound went from costing 3.5 hours of life to costing 5.1.

The lesson is not about which is right; it is that **this app must not hold its
own opinion about the band**. It clamped to `1.15...1.5` on the reasonable-looking
grounds that Attention's method supported nothing else. When Attention's range
widened to `1.0...4.0`, that clamp silently cut a measured 2.05 down to 1.5 and
understated the working week by a quarter — in the flattering direction, which is
the one that must never fail silently. The bound is now read from a single
constant whose comment names the range as Attention's, not this app's.

The `paidHoursPerWeek` field stays editable, annotated with what the diary
measured. Unlike the busy-week selector — which was genuinely being overruled and
rightly stopped looking live — this one is still doing two jobs: setting the
nominal rate, and being the whole of the fallback if the file goes away. A live
control doing real work should look live.

### What it refuses to conclude

Attention's own documentation is emphatic about which of its figures are honest,
and the reader follows it rather than helping itself:

- **Timed work only.** Work typed in afterwards is true but is an estimate, and
  is stamped at the moment it was typed rather than when it happened. It never
  reaches an hourly rate.
- **A day with under three hours timed is not a timed day**, and fourteen of them
  are needed before the overhead figure means anything. Both floors are
  Attention's own, borrowed rather than invented.
- **Medians, never means.** One day spent entirely in a corridor should not
  redefine what an ordinary day costs.
- **`calendarKnown: false` is not an empty day.** This one is worth spelling out,
  because the documentation understates it. The busy figures vanish when nobody
  read the diary, as documented — but checking Attention's `DayDigest.build`
  shows the *free* figures are still written, reporting the whole window as
  though nothing were booked. Averaging them unfiltered wouldn't add noise, it
  would add a nominal free evening for every day nobody looked at. Every free-time
  figure here filters on `calendarKnown` first.
- **Zero means "not learned yet"** for the three calibrated settings, not a
  multiplier of nought.
- **The conventional multiplier is not an estimate correction.** It was read as
  one for a while; see below.
- **A stale file doesn't get to describe the week ahead.** The digest reaches 21
  days forward of the export; past a week old, the busy-week setting takes back
  over and says so.
- **Holidays are excluded from every baseline.** Attention gives a holiday the
  whole day as its life window, so a fortnight in Italy would otherwise redefine
  what a free evening looks like.

### Why setup time and not the whole duration

Attention has learned how this person's estimates of their own effort run. That
correction is applied to setup minutes — the getting ready, the going to fetch
it, the working out where the thing is — and deliberately not to the main
duration, which is as often a looked-up fact as a guess. Correcting a train
timetable by twenty per cent would be inventing a delay.

It comes from Attention's `EffortCalibration`: the median of what work filed as
"under an hour" actually took, against the forty minutes the bucket ships with.
Since you pick the bucket, the bucket *is* your estimate, and the timer is the
actual — so this is your own guess measured against your own stopwatch.

Two things make it conservative rather than confident, and both are deliberate.
Attention discards samples that turned out to belong in a bigger bucket, so the
hour-long job that took three hours is thrown out instead of counted as bias —
the figure understates the drift rather than inventing one. And the measurement
is clamped at the bucket's own label of sixty minutes, so the top of the range
means "at least half as long again", not "exactly".

The `quick` bucket is deliberately unused. Its calibration ceiling is the same
ten minutes as its nominal figure, so it can only ever move *down* and carries
no information at all about work running long. Averaging a censored measure with
an uncensored one would pull the answer towards one for no reason anybody could
name.

### The multiplier that was reading the wrong field

Worth recording because it survived the original audit and is the kind of
mistake that looks like a feature.

The correction above used to be taken from Attention's `conventionalMultiplier`,
on the documented belief that it was "learned from the gap between what they
said something would take and what it took". It is nothing of the sort. It is a
unit conversion:

    conventional ≈ deep × r + meetings,   r = 1.5 − meetings / deep

— the residual overhead a strict timer leaves out, for turning a week of timed
deep work into a conventional one. It says nothing about anybody's estimates.

Three consequences, all live until this was fixed:

- Settings reported **"Your time estimates run 30% over"** from a number that
  means "your deep hours convert to a conventional week at ×1.3". A false claim,
  on screen, presented as a measurement.
- Because `r = 1.5 − meetingShare`, a heavier meeting load *lowers* it — so the
  app was effectively claiming that the more meetings you sit in, the better you
  estimate.
- It scaled setup minutes on both sides of a decision, which scales the
  *difference*, which is what the verdict turns on.

It was clamped to `0.5...3` as well, a band invented here; Attention's own method
supports `1.15...1.5` and nothing outside it. The correctly-named figure is now
carried on the summary, clamped to Attention's range, and wired to nothing —
it belongs to the hours-worked side of the rate, which is still `paidHoursPerWeek`.

It is worth being clear that this is not neutral even though it scales both
sides. It scales the *difference* too, and the difference is what the verdict
turns on.

### What the audit found

Running the whole thing on a realistic 142-day export turned up four things worth
recording, all now fixed:

- **The busy-week selector on the home screen was still live while the diary was
  deciding the week.** A control that looks live and is being overruled is worse
  than no control — the first time you tap it and nothing moves you stop
  believing any of it. It's now replaced by a line saying where the week came
  from, and comes back when the file goes stale.
- **The week's load multiplier was missing from the rate's working entirely.** A
  busy week could raise the rate by a quarter with nothing in the step-by-step
  breakdown accounting for it.
- **Long-horizon verdicts were reported as one large lump.** Blackout curtains
  over five years came out "ahead by £8,973", which is arithmetically right and
  useless. It's now restated as what each occurrence is worth.
- **Long picker values truncated mid-word** ("About wh…hould be"), and the
  savings-goal field shipped pre-filled with the words "savings goal", hiding its
  own placeholder.

Two things were checked and deliberately left alone. A ten-hour learning decision
can get through with no follow-up questions at all, because nothing that could be
asked would change the answer — that is the rule working, not failing. And a
close call can carry four separate caveats, which is a lot, but they sit behind
"Why?" where they were asked for rather than on the answer itself.

### Getting the file

Attention is an optional companion app, and this one reads only a backup file exported
from it: Settings → Attention → "Choose a backup file…". The file is copied into this
app's own storage and used until a newer one is chosen. Nothing is ever written back,
and nothing reaches into another app's storage.

The backup is a JSON file: a list of per-day digests (booked, worked, free and
meeting minutes, whether the calendar was actually read that day), a `workSpan` block
carrying the conversion from timed deep work to a conventional week and its scatter,
a few calibration settings, and sleep times. It carries no event titles, only minute
counts and merged spans, so what reaches this app is how much of a day was spoken
for, never what for. Every field is optional and decoded individually; a file written
by an older exporter is believed on the evidence it has.

## Keeping savings in step with pay

A raise that changes nothing about what you put aside is a raise that quietly
becomes spending. The share saved falls every time you earn more, which is the
most ordinary way anyone ends up no better off on considerably more money.

The app records what you earned and saved the last time the two were in step. When
take-home rises by more than a per cent and more than ten pounds, the home screen
says so once, with two figures: the same share of the new take-home, which is the
floor, and half the increase on top of what you already save, which is usually
affordable because none of the rent or the bills went up with the raise. A goal
amount scales alongside, when there is one.

Three details matter more than they look:

- **It works off take-home, not the headline.** A rise from £38,000 to £46,000 is
  twenty-one per cent on the payslip and eighteen on what actually lands, and the
  eighteen is the honest figure to hold savings to.
- **Accepting re-anchors; declining doesn't.** Say yes and the next raise is
  measured from where you now are. Say no and the reference stays at the last
  point you were genuinely in step, so a skipped raise doesn't quietly lower the
  bar for the one after it.
- **A pay cut moves nothing at all.** Re-anchoring on the way down punishes
  exactly the right behaviour — absorb a cut without touching your savings and
  your share goes up, and the app would then hold you to that raised share for
  ever, demanding more on the way back to a salary you already had. Leaving it
  alone means recovering to your old pay asks nothing, and only pay above it asks
  for more.

## Backing it up

Settings → Backing it up writes one JSON file with your situation, your anchors
and every decision you've saved, and takes one back. Pretty-printed with sorted
keys and ISO 8601 dates, so it's readable by a person and diffable by a tool —
the same shape Attention uses for its own backups.

Restoring replaces everything rather than merging, and says what it's about to do
first: when the file was taken, how many decisions are in it, what hourly rate it
implies, and how many decisions it is about to replace. A merge would leave you
unable to say what state you were in afterwards.

### The one you don't have to remember

A manual export only protects the days you remember to run it. So the app also
writes an unattended snapshot when it opens and one is due — every three days by
default, adjustable to daily, weekly, fortnightly or off — keeping the last eight.
Modelled on Attention's own snapshots, down to the filenames and the count kept.

Three departures from it, each for a reason:

- **Every three days rather than weekly.** A reinstall should rarely cost more than a
  few days of decisions.
- **An unchanged state isn't written.** Eight snapshots of eight identical states
  is one snapshot and seven wasted slots, so the eight kept are eight different
  states rather than eight copies of today. Compared with the timestamp
  normalised, since that's the one field guaranteed to differ and the one nobody
  is restoring for.
- **They're listed in Settings and restorable with a tap**, each showing how many
  decisions it holds. A file picker can't reach an app's private container folder,
  which would make the automatic snapshots unreachable, and an unreachable backup is
  decoration.

They go in this app's own container and deliberately nowhere shared: another app's
reader may take any `.json` in a shared folder as one of its own.

Nothing is snapshotted before setup is finished. That rule exists because the
first version didn't have it: the first snapshot was taken in `Store.init`, which
runs before onboarding, so the oldest snapshot in the list was a pre-setup one
that put you straight back into onboarding if you ever restored it. Found by
restoring it.

This all matters more here than in most apps. Reinstalling is routine rather than
exceptional, and a year of decisions and a carefully tuned set of anchors shouldn't
live only in a container that a reinstall can take away. The automatic snapshots
survive a rebuild; only the exported copy survives deleting the app.

Note that timestamps land to the nearest second: a readable date format doesn't
carry more, and nothing here needs more. Everything else round-trips byte for
byte, which is what the tests actually assert.

## What the audit turned up

**Formatting the answer cost a thousand times more than working it out.** A full
evaluation — every occurrence, the sensitivity sweep, two hundred probes to find the
payback month — runs in 0.002 ms. `Fmt.money` ran in 0.042, because it built a
`NumberFormatter` every call, and a verdict screen formats sixty-odd sums. Two formatters,
built once: 47× faster, same output.

**Nine of the sixteen follow-up questions could never be asked.** The rule everywhere is
"ask only what could change the answer", and it is the right rule — but for some decisions
the question isn't a tiebreaker, it's the fact the answer is made of. £60 of cover against
£0 is decisive on price alone, so nothing flips, so the app never asked how likely the thing
was to break: it settled a warranty by pricing the cover and ignoring the risk, which is the
one calculation that scenario exists to avoid. Twenty scenarios now name the questions they
cannot be answered without.

The same gap ran through the softer terms. "A gig, a trip, a long lunch with someone you
love" is a scenario whose hint says *be honest with that slider, this is the decision where
it should win* — and at £90 against nothing the app asked no questions at all and said save
the money, because the feel term could move £80 and the gap was £90. It never showed the
slider it had just told you to be honest with. The gym was a pure price comparison, which is
not why anyone joins a gym. Thirteen of thirteen feel, health and drain promises are now
kept, against five before; and the relevance thresholds count how many times a thing happens
in a period, so three forty-minute shop trips a week no longer read as forty minutes and
rule out the question about whether they wear you out. All of it costs 0.21 extra questions
on average, against a cap of three.

The two gated terms were the worst of it. Learning fired for one scenario in the thirteen
that declare a task you could get better at, and what it means to other people for two in
seven — every one of them relevant, the gate open, the question simply never put. "Painting,
flat-packs, the leaking tap, the website" asked nothing at all, which meant the detour rule
above — marked as a detour it scores nothing, and the app will tell you to pay someone —
could not be reached in the decision it was written for. "Learn it once, save forever" never
asked whether you'd learn anything. Five scenarios now name those terms as the subject they
are, and the whole app sits at 1.73 questions on average, with 12% still asking none.

One limit stays. The social term speaks in the language of turning up — *they'd be glad I
came*, *they'd really want me there* — so it fits an invitation and not "my child gets more
of me". Childcare against hours, a four-day week, moving further out: other people are
plainly affected and the question cannot ask about it in words that fit. Generalising the
wording would cost the seven scenarios where it reads exactly right, so it stays as it is,
and stays written down here instead.

**Two questions had no business being asked where they were being asked.** Every other
follow-up is gated twice: on the numbers entered, and — where the question only makes sense
for a kind of decision — on the scenario itself. Timetables need a journey, learning needs a
task you could get better at, what-it-means-to-them needs somebody else in the picture. Risk
and scarcity had only the first gate, so a sweep of 32,500 inputs found them surfacing in 25
and 27 scenarios respectively: the app asked how often a birthday party lets you down, and
whether a **parking space** was a chance that comes round again. The first is a category
error and a poaching besides — whether a night out turns out to be any good is what the odds
question is for, and its own note says so. The second applies a multiplier worth up to two
and a half times to an errand.

They now carry the gate they were missing. Risk needs something that can fail to be
delivered — a train, a tradesman, a lodger, a delivery slot — which is 29 of the 52. Scarcity
needs an occasion, which is three: the gig, the party, the night out that childcare has to be
paid for. Nothing was asked less often as a result; the average moved from 0.99 questions to
1.00. The nonsense was replaced rather than removed, which is the point.

One scenario was the warranty problem again, exactly. "Fast-track passport, express visa,
next-day anything" — £300 of speed against £0 is decisive on price alone, nothing flips, and
so the app never asked the only thing that justifies the fee: whether there's a date you
can't move. It priced the fee and ignored the deadline. It now leads with *what if it goes
wrong*, and "I cannot miss this" is one of the answers. At £142 against £88 with the standard
service sometimes late, the fee buys £38.74 of expected loss avoided — still not worth £54,
but close enough that the app says so rather than pretending it was obvious.

**The question ordering was settled in the wrong units.** Once a question is known to
change the verdict, the planner picks between the survivors on how far each one moves the
margin — and it measured that in pounds. But two of the sixteen multiply the whole decision
(*will you do this again*, *how many times each*) while the other fourteen add a bounded
amount to one side of it. So the multiplying two won on arithmetic rather than on
information: *will you do this again* beat *would you do it tomorrow anyway* into second
place 468 times, by a median factor of seven, for the sole reason that fifty-two pints cost
fifty-two times one pint. The margin is now measured as a share of the decision it belongs
to, so pure scaling cancels and only a real change in the balance counts. Every spread in
the app now lands between 0 and 4; the largest before was £91,463.

Nothing is lost by asking *will you do this again* less often, because the verdict already
answers it for free: every one-off decision carries a line saying what the gap becomes as a
weekly habit, whether or not the question was put. It had been spending one of three slots
to obtain something printed on the next screen. Across 32,500 inputs it drops from 1.6% of
all questions asked to 0.7%, and *would you do it tomorrow*, *what if it goes wrong* and
*can you use that time* take up the slack. The total asked barely moves: 1.00 to 1.02.

Two things fell out of that. The baseline seeded the range with an unsigned margin while
every variant used a signed one, so whenever the second option was winning, the spread
included about twice the advantage in movement that never happened — real, and almost
inert, changing the next question in 19 rankings out of 31,514. And *the gym at eleven at
night* turned out to name a question it could not reach: **would you do it tomorrow** only
applies once there is something worth postponing, which the app learns by asking how it
would feel — and feel was not one of that scenario's named questions, so the gate never
opened inside the three-question budget. It now names what unlocks it, and asks all three.

**The other multiplying question offered three lodgers for one spare room.** *How many
times each* multiplies an option's money and its time together. That is exactly right for
one delivery a week against three trips to the shop, and it is nonsense for anything
charged once per period — and the question was offered on all thirty scenarios that recur,
with no test of which kind it was. Answering "three times each" on the spare room turned
£7,907 of rent into £24,439 of it; on the four-day week it tripled a salary, and on nursery
fees it produced £33,838. Fifteen scenarios now say they are made of countable things — a
trip, a wear, a meal, a journey — and the other fifteen, where the money is a standing
charge, are no longer asked.

It was also arguing with answers it had just been given. Four scenarios put "how many times
each" on the entry form, because for those the two sides plainly don't happen at the same
rate. Filling it in there did not stop the app asking **how many times each, though?** two
screens later — and on the gym it asked *sooner* for having been told. It now takes the
answer. Across the sweep the question drops from 10.1% of everything asked to 5.9%, and the
total asked falls slightly, from 1.02 questions to 0.99.

**And the count it sets was multiplying the wrong things.** "How many times each" scaled an
option's money and its time as a pair, which is right for a trip to the shop and wrong for
the three scenarios the count matters most in. A gym membership is billed monthly however
often you turn up, and eight visits made it eight subscriptions: £487 a year became £4,327.
The same shape sat under the season ticket and the car. Money and time are now counted
separately — the money on its own cadence, the clock always per go — and each side says
which it is on the row itself: **Cost a month** against **Cost each time**, with a tap to
switch, appearing only once the count is above one, where the difference exists. At £40 a
month against £6 a swim the membership now holds at £487 whatever the visits, and the answer
turns over between four and eight — either side of the 6.7 where £40 and £6 actually cross.

Inflation was compounding on the same mistake. The rate is per period, and it was being
applied once per go, so eight visits a week charged a single year at eight years of
inflation: 1.5% became 12.8%. One period's charge, inflated over the periods, and the uplift
is now the same 1.5% at every count.

**Every field ever added to a saved decision was a trapdoor under it.** Synthesised decoding
throws on a key it cannot find, defaults and all, so a decision written before a field
existed could not be opened at all — six of them were fatal that way, and all thirty-one of
the profile's were. The earlier fix kept one failure from taking the other down with it;
this one stops the failure. Both now decode field by field, falling back to what a new one
would have had, so the next setting added here costs nobody their history.

**One more term was counting a single occurrence inside a total made of many.** Having found
the same mistake twice, the obvious next question was whether any other multiplier had it —
so every term was tested the same way: build a decision that exercises all of them, then
stretch the horizon tenfold and raise the count fourfold, and see what moves. Money, hours,
enjoyment, what it means to others, health and learning all moved, each by the amount its
own damping implies. The risk of it going wrong did not move at all: the same £46 over one
year and over ten, at once a month and at four.

It was the expected cost of exactly one mishap, added into a sum where everything else had
counted every occurrence. The intent was already in the code — one comment explains that the
cost of a bad outcome is deliberately *per occurrence*, "not what a decade of them would" —
and that only makes sense if something afterwards counts the occurrences. Nothing did. It
now multiplies by the same count as health and enjoyment, so a lodger with a one-in-twenty
chance each month of not paying £650 costs £390 of expected loss a year, rather than the £33
of a single month. The one-off decisions are unaffected, warranties and fast-track fees among
them, because for those the count was one all along.

The property this breaks is now checked directly, in all fifty-two: on a decision that
recurs, every non-zero term must grow when the horizon grows. Putting the old line back makes
it fail, which is the only evidence that a test is worth having.

**So there is now a field for what the thing is worth.** Until it existed the app had to
guess what a bad outcome costs from the largest figure in front of it, which on a warranty
is the cover itself: £60 of protection on an £800 machine reckoned a breakdown set you back
£60, and priced the cover against a tenth of what it was covering. "How much would it cost?"
appears under *it'd cost me money*, and only there — the other answers are priced off the
anchors because what they cost isn't money. Left empty it keeps the old guess, which is
right more often than not: a lodger who doesn't pay costs you the month's rent, and that is
already on the screen. Nothing moves in any of the fifty-two scenarios while it is unset.

With it, the warranty finally does its own arithmetic. Cover at £60 against a machine that
fails one year in five is worth it above about £300 of machine and not below, and the answer
now turns over exactly there.

Two things were in the way of it. The first: on a "should I?" decision the app hides the
second option, because it is normally an untouched do-nothing. For this one question that is
false — going without the cover is not doing nothing, it is the side that lets you down —
so a warranty could be told how often the insurer fails and never how often the machine
breaks, on a question it insists on asking. The same hole sat under three other should-I
decisions where something can go wrong. The second: with both sides showing, they were
labelled from their numbers, and "the cheaper one" is a true and useless way to refer to
going uninsured. A should-I decision now names its branches the way the scenario does —
**Buy the cover** and **Go without** — which asserts nothing about the figures.

What remains is the fallback itself. Leaving the field empty on a warranty still reaches for
the cover price, because that is the largest number on the screen, and it is the one
scenario where that guess is reliably wrong. The field is the answer; it just has to be
filled in.

**The hidden second side went much wider than insurance.** Having found one field the screen
could not reach, the next question was how many others there were — so every field the engine
reads was traced back to the control that sets it. The per-option ones all go through the
same place, and on a "should I?" decision that place shows one card. Which is right when the
other side is nothing, and a claim about the world when it isn't:

| the decision | the other side | what it was scored at |
|---|---|---|
| Squeeze it in, or leave it | **Leave it and rest** | not restful, not restorative, zero |
| Take a lodger | **Keep the place to myself** | privacy worth nothing |
| Extra work vs free time | **Keep the time** | the time worth nothing |
| Go out, or stay in | **Stay in** | a night in worth nothing |
| Is it worth buying? | Don't | correctly nothing |

Nine of the twelve were a described alternative rather than an absence. The app was asking
"how would **each one** feel?" and then taking an answer about one of them — and the planner
had never agreed: it decides whether to ask by moving *both* sides, so it was ranking a
question wider than the screen could accept. Worst of it was the scenario about whether to
rest, where resting could not be called restful, and the lodger, whose own hint says the feel
slider decides it while privacy scored zero.

Templates now say which of the two it is, and only "Don't", "Don't" and "Go without" are
blank. The other nine show both sides, named the way the scenario names them — **Do it now**
against **Leave it and rest** — because a side described by its numbers comes out as "the
cheaper one", which is a true and useless way to refer to going uninsured or staying home.

Everything the engine reads was then traced the other way, from the field back to the thing
that sets it. All twenty-one per-option fields have a control, and so does every
decision-level one bar the cadence of the one-off leg, which belongs to the scenario's shape
rather than to the person — rent is monthly whether or not the commute is daily, and the two
legs are counted independently, so no setting of "Happens" can put them at odds. Two profile
values have no control because they are bookkeeping the app keeps on its own: the income it
last saw, and the fact that a savings suggestion was turned down. Nothing has a control that
nothing reads. Where a question is gated off by scenario, the field it sets stays at a
genuinely neutral default — a multiplier of one, or nothing at all — so a question never
asked can never quietly take a side.

**The controls that were there disagreed with the words above them.** Three scenarios say
which side of them is a standing charge and which is priced per go, and two were saying the
opposite of their own instructions. "Everything the car costs per month" sat above a taxi
figure the app multiplied by the journeys. And the season ticket asked for "what you'd
otherwise spend each month" while its blurb promised a break-even on how often you go — so
the count had nothing to work on, and multiplied the monthly total on the occasions it was
given one. Both predate the cadence itself: money used to be multiplied by the count for
everybody, so the words and the arithmetic had been at odds all along and the new flag merely
inherited it.

The car now counts both sides by the month, as its hint says, and the journeys move only the
hours. The season ticket asks for the single fare and how many journeys, which is the sum its
blurb describes and the same shape the gym already used: a £1,400 pass against a £9.60 fare
turns over at twelve journeys a month, and the break-even is 12.2. A declared cadence is now
checked against the arithmetic in all fifty-two — per go must scale with the count, per
period must not.

**Then every hint was read against the fields its scenario actually shows.** A hint is an
instruction, so it can be wrong in two directions: sending somebody to a field that isn't
there, or leaving unexplained one that is. Fifty of the fifty-two matched. The two that
didn't both put a count box on the form and never said what it was for — on eat out against
cook, which the app itself calls the most frequent decision there is, and on the cheaper shop
further away. Both now say it: two takeaways against five home dinners is the whole shape of
one, and one big shop against three local ones is the point of the other.

Five more looked wrong to the checker and were not. "How long it'd last in Counted over"
sends you to the horizon picker on purpose; "the app works out how many times you'd buy the
cheap one" is describing what it computes rather than asking for it; and "tonight buys you
very little" is about sleep, not about anything wearing out. The check is now kept, tightened
enough to stay quiet on all fifty-two, so the next scenario added can't drift from its own
instructions.

**A one-off can still be made of repeated units.** Selling thirty things one by one used to
say "multiply by how many items — honestly", because the count only ever showed on a decision
that recurs: the row is labelled "Times a week", and "Times a once" is not a label. The
arithmetic never needed the recurrence — one occurrence of thirty goes is thirty goes — so
the row now reads **How many** when there is no cadence to name, and the same for the price
above it and the record underneath. One item's worth and a number, instead of a multiplication
done in your head: £18 and 25 minutes and thirty of them comes to £540 and twelve and a half
hours, which is the sum the hint had been asking you to do.

**"The cheaper one" described the winner without identifying it.** Options are named from
the numbers entered, so that the wording can never contradict the data — which is the right
instinct and, on a decision between paying £210 once and £9 a month, produces a verdict
reading *the cheaper one* over *£210 up front*. Both true. Neither says which of the two
things you were choosing between actually won, and somebody has to stop and work it out.

Fifty-one of the fifty-two scenarios already have a plain name for each side — **Buy it
outright** and **Subscribe**, **Membership** and **Pay each time** — and those names cannot
contradict the figures, because they are the labels on the cards the figures were typed
into. So they are used first now, and the numbers describe only where there is nothing else
to go on: "Getting somewhere" offers *e.g. Uber* as a suggestion for a field you fill in
yourself, and a custom decision has only Option A and Option B. A name you type still beats
both. The whole verdict follows: *Subscribe costs more, £1,045*, *Buy it outright, per use
£1.75*, *Subscribe gives up more growth*.

**And the cursor started in the wrong box.** It opened on the monthly field, which is right
for a gym membership and wrong for the thirteen scenarios that are *made of* their one-off
figure — the purchase price, the course fees, the excess, the price of the pass. On those
the hint says "purchase price in the one-off field" while the caret sits in the box above
it, one unnoticed keystroke from reading £210 as £210 a month, which is the exact mistake
that scenario exists to prevent. Those thirteen now open on the field they are about.

**Five smaller things, from using it.** The first tile is the one scenario the app cannot
name for itself — it could be any two of a dozen ways to travel — so it offers the usual
suspects as one-tap chips, and *the cheaper one* becomes *the bus*. The keyboard grew a next
and a previous, because a two-sided decision with a one-off leg is eight number boxes and
every one of them wanted its own tap. The one-off *time* row now appears only where the
scenario has named it — twelve decisions were drawing an empty "One-off time, 0h 0m" on both
cards, including the cleanest comparison in the app. The verdict gives a small haptic when it
lands. And the three pills on the rate card go one to a line at accessibility text sizes,
where "Balanced" had been hyphenating to "Bal-an-ced" inside a circle and £848 spare was
breaking mid-number.

**A decision you record tightens the decisions after it — for thirty days.** Buying
something for £210 books the whole £210 against the next month, so your hour is worth 57p
less until it falls out of the window, and the app stops telling you that you have money you
have already spent. For a purchase that window is exactly the right shape: it came out of
this month's money and next month's is untouched.

For anything that recurs it was the wrong idea rather than the wrong number. Saying yes to
£9 a month booked one month's worth and then forgot, while the £9 carried on leaving the
account — so from the second month the app believed in money that wasn't there. A standing
cost belongs in the standing costs, and the profile has had a figure for those all along, so
recording a recurring choice now offers to put it there: *add £9 to your monthly bills?* It
then counts permanently, sits where anybody would look for it, and comes off in settings when
the thing is cancelled. Accepting also takes the same £9 back out of the thirty-day ledger,
or the first month would count it twice — once as a bill and once as something just taken on.

### Noted, not fixed

Small enough to leave, and written down so they aren't lost:

- **The one-off leg's cadence** is fixed by the scenario and has no control. Rent is monthly
  whether or not the commute is daily. Verified harmless — the two money legs are counted
  independently — but a custom decision can't say that its one-off cost recurs.
- **A warranty left blank** still prices the risk off the cover, because that is the largest
  figure on the screen. The field for what the thing is worth is there; it has to be used.

**A new field in any future version would have wiped every saved decision.** Synthesised
decoding throws on a key it can't find, defaults and all, and the loader's `try?` fell
through to an empty state — which the next save then wrote over the top. The profile and
the decisions are now decoded apart, so one failing can't take the other with it, and a
file that can't be read at all is kept rather than overwritten. A profile is fifteen
questions; the decisions behind it are not replaceable.

**Situations can be hidden.** Long-press any of them. Hidden is a shelf, not a bin: search
still finds them, saved decisions still open, and settings brings them back — because the
one you hid in March is the one you need in June.

## Known judgement calls

The dials most worth arguing with, all in one place:

- **35/65** — how much the blended rate leans on your wage versus your spare money.
- **`n^0.6`** — how fast enjoyment fades with repetition. Health uses `n^1`.
- **£4, £60 and £40** — the health, enjoyment and learning anchors. All adjustable.
  Health is the arguable one: working back from the £20,000–£30,000 a quality-adjusted life
  year is valued at in UK health economics lands nearer £1 than £4. The higher figure
  deliberately includes energy, sleep and mood, and errs towards valuing health.
- **2% real return, 0% bonus** — what money would have done if you hadn't spent it.
- **3% inflation** — grows future costs, restates past spending.
- **×1.3 when ahead** — and only when there's slack to be ahead with.
- **10 minutes** — the flat cost of having to decide and organise something, each time.
- **×2.5 for sleep** — deliberately punitive, and the most arguable multiplier here.
- **1.4 × the enjoyment anchor** for "they'd really want me there" — above parity with
  your own best evening, which is a judgement. People consistently treat obligations to
  those they love as outweighing their own preferences, and on the whole they're right to.
- **0.2** — how much of a benefit survives being postponed to tomorrow.
- **×1.3 / ×1.8** — what hours cost when they come out of work that can slip, or can't.
- **£1 and 10 minutes** — how alike two options have to be before the app stops asking
  questions and simply names the cheaper one.
- **×1.25 / ×0.8** — what a busy or quiet week does to your rate.
- **`0.6 × √scale`** — the band inside which the arithmetic gives way to a tiebreak.
  Square-rooted rather than proportional, so it's about £2 on a £10 decision and about
  £55 on an £8,400 one.

## Signing and App Groups

The widget reads what the app writes through an App Group, `group.<APP_BUNDLE_PREFIX>`.
App Groups need a correctly provisioned team on a device; on a simulator they work
unsigned. If a device build complains that the profile doesn't match the entitlements,
the usual cause is an App ID that hasn't picked up the capability yet: enable App Groups
for the target in Xcode's Signing & Capabilities and build again.

## Tipping point and verdict agree

The tipping-point sentence used to compare your rate with the threshold and name the
winner from that alone, while the verdict could have fallen back on "the cheaper one"
inside the noise band. For a narrow range of rates just above the tipping point the
headline and the sentence then named different options (at £32.10 an hour: the bus, and
"Uber wins"). The sentence now names the side the verdict actually chose, and says so
when the call is close. `DecisionEngineTests` sweeps rates either side of the threshold
to keep the two in step.

## Money rounding

`Fmt.money` used the formatter's default half-even rounding, so £1,234.50 printed as
£1,234 and £100.50 as £100. Halves now round up.
