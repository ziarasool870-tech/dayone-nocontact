/// 90-day guided program: one 2-minute healing task per day.
/// Tone: a wise, warm friend sitting beside a heartbroken person.
library;

/// A single day's guided task.
class ProgramTask {
  const ProgramTask({
    required this.day,
    required this.title,
    required this.opener,
    required this.action,
  });

  /// 1..90.
  final int day;

  /// Short task title (3-7 words).
  final String title;

  /// 1-2 warm lines setting the emotional tone (max ~40 words).
  final String opener;

  /// One concrete 2-minute action, doable RIGHT NOW.
  final String action;
}

/// All 90 tasks in journey order. Day N unlocks on no-contact Day N.
const List<ProgramTask> programTasks = <ProgramTask>[
  ProgramTask(
    day: 1,
    title: "Just Breathe Tonight",
    opener: "Today doesn't need a plan. It just needs you breathing through it. You're on Day 1, and that alone took courage.",
    action: "Sit down, set a timer for 60 seconds, and breathe in for 4 counts, hold for 4, out for 4. That's the whole task.",
  ),
  ProgramTask(
    day: 2,
    title: "Name Today Honestly",
    opener: "Feelings get louder when we won't name them. Giving today one honest name shrinks it down to something you can hold.",
    action: "Open your journal and write 3 lines: 'Today I feel ___ because ___.' No fixing, no judging — just the truth.",
  ),
  ProgramTask(
    day: 3,
    title: "One Hour at a Time",
    opener: "Ninety days sounds impossible. One hour doesn't. Forget the whole day — let's just get you through the next sixty minutes.",
    action: "Pick ONE small thing for the next hour: a shower, a walk, a meal. Write it down. Do only that.",
  ),
  ProgramTask(
    day: 4,
    title: "Drink a Glass of Water",
    opener: "Heartbreak dehydrates in more ways than one. Your body is doing hard work today, and it needs the basics.",
    action: "Stand up right now, pour a full glass of water, and drink all of it slowly. Notice how it feels going down.",
  ),
  ProgramTask(
    day: 5,
    title: "Move for Two Minutes",
    opener: "Grief lives in the body, and the body is asking to move. You don't need a workout — you need two minutes of motion.",
    action: "Set a 2-minute timer and shake it out: roll your shoulders, stretch your neck, march in place. Move until the timer ends.",
  ),
  ProgramTask(
    day: 6,
    title: "If You Texted Yesterday",
    opener: "If you broke no-contact yesterday, listen: you are not starting over from nothing. You're still here, and that counts more than a perfect streak.",
    action: "Write one line in your journal: 'I slipped, and I'm still healing.' Then re-read your Day 1 reason for starting. Keep going.",
  ),
  ProgramTask(
    day: 7,
    title: "Build Your 3am Kit",
    opener: "The hardest hour is the one when the world is asleep. Let's prepare for it now, while the sun is up and you're thinking clearly.",
    action: "Write a short note to your 3am self: 3 things to do instead of texting them (water, breathing, this app). Keep it by your bed.",
  ),
  ProgramTask(
    day: 8,
    title: "Eat One Real Thing",
    opener: "You've been running on adrenaline and empty. Food won't fix the heartbreak, but it will steady the hands that are holding it.",
    action: "Make or get one real meal — not just snacks. Sit down and eat it without your phone. Taste three bites on purpose.",
  ),
  ProgramTask(
    day: 9,
    title: "Mute Them for Today",
    opener: "You don't have to decide about them forever today. You only have to decide about the next 24 hours. Make those hours quieter.",
    action: "Mute or hide their profile on the one app you check most. Not a dramatic block — just one quieter day.",
  ),
  ProgramTask(
    day: 10,
    title: "The Cold Water Reset",
    opener: "When your thoughts are spinning too fast to catch, your body can interrupt the loop. Cold water is the fastest circuit breaker there is.",
    action: "Go to the sink and splash cold water on your face three times, slowly. Then hold a cold glass against your cheek for 30 seconds.",
  ),
  ProgramTask(
    day: 11,
    title: "Two Minutes Outside",
    opener: "Walls shrink when your heart is hurting. The sky is bigger than this feeling, and it's been waiting for you to look up.",
    action: "Step outside — balcony, doorstep, anywhere — and stand there for 2 full minutes. Feel the air, name 3 things you see.",
  ),
  ProgramTask(
    day: 12,
    title: "Say It Out Loud",
    opener: "The thing you're carrying gets lighter the moment it leaves your mouth. No one needs to hear it. You just need to say it.",
    action: "Alone, out loud, say: 'I miss them, and I'm still here.' Say it twice. Notice how your chest feels after.",
  ),
  ProgramTask(
    day: 13,
    title: "One Sentence to a Friend",
    opener: "You don't have to explain the whole story. One honest sentence to one person is a bridge back to the world.",
    action: "Text one friend exactly this (or your own version): 'Hey, I'm having a rough week. No need to fix anything — just wanted you to know.'",
  ),
  ProgramTask(
    day: 14,
    title: "A Note to Future You",
    opener: "Two weeks. That is not small. Somewhere ahead of you is a version of you who made it — let's leave them a message.",
    action: "In your journal, write a 3-line note to yourself on Day 30: what today feels like, and one hope. You'll read it then.",
  ),
  ProgramTask(
    day: 15,
    title: "Write the Text, Don't Send It",
    opener: "The urge to text them isn't weakness — it's love with nowhere to go. Let's give it somewhere to go that isn't their phone.",
    action: "Open the letter vault and write the exact message you want to send. All of it. Then seal it. It's heard — just not by them.",
  ),
  ProgramTask(
    day: 16,
    title: "Anger Has a Body",
    opener: "Anger is not the enemy of healing — it's part of it. It's energy, and energy needs somewhere to go besides back to them.",
    action: "Set a 60-second timer and punch a pillow, hard, until it ends. Then shake your hands out and take 3 slow breaths.",
  ),
  ProgramTask(
    day: 17,
    title: "What Do You Actually Miss?",
    opener: "Sometimes we miss the person. Sometimes we miss the routine, the future we pictured, the feeling of being chosen. Let's get specific.",
    action: "Journal: finish this sentence 3 times — 'I miss ___.' Be brutally specific. Read them back and notice which ones are about them, and which are about you.",
  ),
  ProgramTask(
    day: 18,
    title: "Skip the Song",
    opener: "There's a song that undoes you in four seconds. Today you get to prove — just once — that you can hear the first note and choose differently.",
    action: "When that song comes on today (or play the first 5 seconds on purpose), skip it before the chorus. Say out loud: 'Not today.'",
  ),
  ProgramTask(
    day: 19,
    title: "Lonely Is Not the Same as Alone",
    opener: "Loneliness is a feeling, not a fact. And feelings, even the big ones, are visitors — they arrive, and they leave.",
    action: "Write in your journal: 'Right now I feel lonely because ___.' Then add: 'One thing that is still mine: ___.'",
  ),
  ProgramTask(
    day: 20,
    title: "The Photo You Keep Opening",
    opener: "You know the one. The photo you open like pressing a bruise. Today it goes somewhere it can't ambush you at midnight.",
    action: "Move that one photo (and any like it) into a locked folder or the letter vault — out of your camera roll. You're not deleting memories; you're choosing when to visit them.",
  ),
  ProgramTask(
    day: 21,
    title: "Good Memories Are Allowed",
    opener: "Healing doesn't mean rewriting the story so it was all bad. Some of it was genuinely good — and you can keep that without keeping them.",
    action: "Write down one good memory, exactly as it was. Then write one line underneath: 'I'm grateful it happened. I'm healing anyway.'",
  ),
  ProgramTask(
    day: 22,
    title: "The Blame Audit",
    opener: "At 2am, everything feels like your fault. In daylight, let's look at the actual ledger — because guilt lies, but lists don't.",
    action: "Draw two columns: 'Mine' and 'Theirs'. Write what honestly belongs in each about why it ended. Read it back slowly.",
  ),
  ProgramTask(
    day: 23,
    title: "The Two-Minute Body Scan",
    opener: "Your mind has been screaming for weeks. Your body has been whispering underneath it. Two minutes — let's listen to the whisper.",
    action: "Lie down, close your eyes, and slowly notice: jaw, shoulders, stomach, hands. Wherever you find tightness, breathe into it for 3 breaths.",
  ),
  ProgramTask(
    day: 24,
    title: "If You Slipped Again",
    opener: "So you texted. Or called. Or drove by. Okay. Healing isn't a straight line — it's a direction. You're still facing the right way.",
    action: "Write what happened in 2 honest lines — no excuses, no drama. Then write: 'What I'll do next time the urge comes: ___.' That's growth, not failure.",
  ),
  ProgramTask(
    day: 25,
    title: "Say Their Name",
    opener: "You've been avoiding their name like it's a live wire. It's just a name. Today it loses a little of its power.",
    action: "Out loud, say their name once, followed by: '...and I'm healing.' Repeat 3 times. Notice it getting smaller each time.",
  ),
  ProgramTask(
    day: 26,
    title: "One Full Sentence",
    opener: "You've been living in fragments — half-thoughts, flashes, spirals. One complete sentence can be an anchor in all that static.",
    action: "Journal, one full sentence only: 'Today, the hardest moment was ___, and I got through it by ___.' Read it twice.",
  ),
  ProgramTask(
    day: 27,
    title: "Delete One Digital Thing",
    opener: "Your phone is a museum of them. You don't have to burn the museum down — just close one exhibit today.",
    action: "Delete ONE thing: an old chat thread, a saved voicemail, their contact photo — your pick. One. Notice the tiny lightness after.",
  ),
  ProgramTask(
    day: 28,
    title: "The Empty Chair",
    opener: "There's a space at your table, in your car, in your day where they used to be. Ignoring the space doesn't fill it — but you can.",
    action: "At your next meal, sit somewhere new and put something of YOURS where they used to sit — a book, flowers, your journal. Reclaim the seat.",
  ),
  ProgramTask(
    day: 29,
    title: "When Your Mind Makes Movies",
    opener: "Your brain keeps directing films: them happy without you, them with someone new. Those are horror movies you didn't buy a ticket for.",
    action: "When the movie starts today, say out loud: 'That's a story, not a fact.' Then name 3 real things in the room you're actually in.",
  ),
  ProgramTask(
    day: 30,
    title: "Cry on Purpose",
    opener: "You've been crying at random — in traffic, in the shower, mid-sentence. What if, just once, you chose the time and place?",
    action: "Set a 2-minute timer, put on something that moves you, and let it come — on purpose. When the timer ends, wash your face and step outside.",
  ),
  ProgramTask(
    day: 31,
    title: "Park the Why",
    opener: "Why did this happen? has no good answer at 3am — and honestly, no satisfying one at 3pm either. Let's park it.",
    action: "Write every 'why' question swirling in you into your journal — all of them. Then close the journal and say: 'Parked. I'll live the questions instead.'",
  ),
  ProgramTask(
    day: 32,
    title: "Hold Something Warm",
    opener: "Your nervous system doesn't speak English. It speaks temperature, pressure, rhythm. Let's talk to it in its own language.",
    action: "Make tea, coffee, or just warm water. Hold the mug with both hands for 2 full minutes. Feel the warmth travel up your arms.",
  ),
  ProgramTask(
    day: 33,
    title: "One Kind Sentence in the Mirror",
    opener: "You've been saying cruel things to the person in the mirror. Today that person gets one kind sentence. Just one.",
    action: "Look yourself in the eyes and say: 'You're doing harder than anyone knows, and you're still going.' Mean one word of it.",
  ),
  ProgramTask(
    day: 34,
    title: "Don't Take the Long Way",
    opener: "You know the route that goes past their street. You know why you take it. Today, take the boring road — the one that leads home.",
    action: "If you catch yourself rerouting toward them today — their street, their cafe, their gym — stop, turn around, take your normal way. Notice the pride after.",
  ),
  ProgramTask(
    day: 35,
    title: "Read Your First Week",
    opener: "Thirty-five days ago you could barely breathe through an hour. Let's check the receipts — your own words, from the hardest week.",
    action: "Open your journal to Days 1-7 and read them slowly. Then write one line to that person: 'Look how far we've come.'",
  ),
  ProgramTask(
    day: 36,
    title: "What Did You Give Up?",
    opener: "Somewhere in that relationship, you quietly shelved parts of yourself — a hobby, a friend, a dream. The shelf is still there. So are you.",
    action: "Write down 3 things you stopped doing while with them. Circle the one you miss most. That's your next project.",
  ),
  ProgramTask(
    day: 37,
    title: "Reclaim One Song",
    opener: "They don't own the music. That song was yours before it was 'ours,' and it can be yours again — it just needs one brave replay.",
    action: "Play one 'their' song all the way through, on purpose, while doing something you love. When it's over say: 'Mine again.'",
  ),
  ProgramTask(
    day: 38,
    title: "Cook Something for Yourself",
    opener: "Cooking for one can feel like the saddest sentence in the world — or the most radical act of care. Today, choose radical.",
    action: "Make one simple thing just for you — eggs, pasta, toast done properly. Plate it nicely. Eat it like you matter, because you do.",
  ),
  ProgramTask(
    day: 39,
    title: "The Friend You Neglected",
    opener: "Relationships eat friendships quietly. Someone you love got the leftovers of you for a while. Today's a good day to fix that.",
    action: "Text one old friend: 'I've been a bad friend lately and I miss you. Coffee this week?' Send it before you overthink.",
  ),
  ProgramTask(
    day: 40,
    title: "Walk a New Route",
    opener: "Your feet know the old paths by heart — past their place, your old spots, the whole map of us. Time to draw a new map.",
    action: "Take a 10-minute walk on a street you've never walked. Notice 5 new things. This is your brain learning the world is bigger.",
  ),
  ProgramTask(
    day: 41,
    title: "Design Your Morning",
    opener: "Mornings used to start with them — a text, a thought, a habit. Now mornings are unclaimed land. Claim two minutes of it.",
    action: "Write your 2-minute morning ritual: e.g., water plus stretch plus one journal line. Do it tomorrow. Mornings are yours now.",
  ),
  ProgramTask(
    day: 42,
    title: "The Unsent Thank-You",
    opener: "Gratitude and grief can sit at the same table. You can be thankful for what was real without wanting it back.",
    action: "In the letter vault, write them a thank-you for ONE real thing — not a love letter, a thank-you. Seal it. Gratitude, not longing.",
  ),
  ProgramTask(
    day: 43,
    title: "Three Things You're Good At",
    opener: "Heartbreak has a way of editing your resume down to one line: 'person who got left.' Let's restore the full document.",
    action: "Write 3 things you're genuinely good at. Stuck? Text a friend: 'Quick — what am I good at?' Write down what they say, word for word.",
  ),
  ProgramTask(
    day: 44,
    title: "One Small Brave Thing",
    opener: "Courage isn't leaping off cliffs. It's tiny: the email, the class, the conversation you've been circling. Two minutes of brave.",
    action: "Do one small brave thing today: send the email, sign up for the class, make the call. Write what you did in your journal.",
  ),
  ProgramTask(
    day: 45,
    title: "The Middle Is Not the End",
    opener: "Day 45. If you slipped this week — or this whole stretch felt like surviving, not healing — hear this: the middle is supposed to be messy.",
    action: "Write 2 lines: the hardest part of this middle stretch, and one thing that's even 1% easier than Day 1. Both are true.",
  ),
  ProgramTask(
    day: 46,
    title: "Wear the Thing",
    opener: "There's an outfit they never liked, or one you stopped wearing because it felt too 'you.' Your closet is a time capsule — open it.",
    action: "Wear the thing today — the bold color, the old favorite, the you-est thing you own. Notice how your spine straightens.",
  ),
  ProgramTask(
    day: 47,
    title: "The Parked Dream",
    opener: "Before them, after them, underneath all of this — there was something you wanted. It didn't die. It just went quiet.",
    action: "Journal: 'One thing I want that has nothing to do with anyone else: ___.' Write the smallest first step under it.",
  ),
  ProgramTask(
    day: 48,
    title: "Teach Yourself Something",
    opener: "Your brain has been running the same painful loop for weeks. Give it a new track — something useless, joyful, and entirely yours.",
    action: "Watch or read a 2-minute tutorial on something fun: a card trick, 5 words in a new language, a sketch technique. Try it once.",
  ),
  ProgramTask(
    day: 49,
    title: "Rearrange One Corner",
    opener: "Your space still holds the shape of two people. You don't need a full makeover — just one corner that says 'me' now.",
    action: "Pick one corner, shelf, or drawer and rearrange it completely — move 5 things. Stand back. That's yours.",
  ),
  ProgramTask(
    day: 50,
    title: "Letter to Day 90",
    opener: "Halfway. The person reading this on Day 90 is real, and they're waiting to hear from you — the you who made it this far.",
    action: "In the letter vault, write a short letter to your Day 90 self: how today feels, what you hope is true by then. Seal it.",
  ),
  ProgramTask(
    day: 51,
    title: "Practice Saying No",
    opener: "Somewhere along the way, 'no' got rusty. Boundaries are a muscle, and muscles come back with small reps.",
    action: "Say no to one small thing today — an invite you dread, a favor you resent, a plan you don't want. Kindly, firmly. Notice you survive.",
  ),
  ProgramTask(
    day: 52,
    title: "Find Your Laugh",
    opener: "You haven't laughed — really laughed — in a while. It's still in there. It just needs an invitation.",
    action: "Watch or read one thing that's always made you laugh — a clip, a comic, a friend's voice note. Let it happen. Two minutes.",
  ),
  ProgramTask(
    day: 53,
    title: "The Survival List",
    opener: "You've survived 100% of your worst days so far. That's not luck — that's evidence. Let's put it on paper.",
    action: "List 5 hard things you've survived in your life — not just this breakup. Read the list out loud. That's your track record.",
  ),
  ProgramTask(
    day: 54,
    title: "Take Yourself for Coffee",
    opener: "A table for one is not a tragedy — it's a date with the most important person in your recovery. Show up for them.",
    action: "Go get coffee, tea, or a treat — alone, on purpose. No phone scrolling. Just sit, sip, and watch the world for 10 minutes.",
  ),
  ProgramTask(
    day: 55,
    title: "One Tiny Money Kindness",
    opener: "Breakups are expensive in every way. Today, do one small financial thing that's purely for future-you.",
    action: "Set aside a little money — even five dollars — into savings, cancel one subscription you don't use, or write a 2-minute budget note. Small counts.",
  ),
  ProgramTask(
    day: 56,
    title: "The Memory Box",
    opener: "The ticket stubs, the hoodie, the little things. Deleting them feels wrong; tripping over them feels worse. There's a third option.",
    action: "Gather the keepsakes into ONE box or bag. Not trash — a box. Put it somewhere out of daily sight. You're curating, not erasing.",
  ),
  ProgramTask(
    day: 57,
    title: "Call, Don't Text",
    opener: "Your person — the one who's been checking in — deserves to hear your actual voice. And you deserve to be heard, not just read.",
    action: "Call one person who cares about you. Two minutes is enough. Say: 'Just wanted to hear your voice.' Let them talk too.",
  ),
  ProgramTask(
    day: 58,
    title: "Start the Compliment File",
    opener: "Your inner critic has had the microphone for weeks. Time to build the case for the defense — one compliment at a time.",
    action: "In your journal, start a 'nice things' page. Write today's entry: one genuine compliment about yourself. Add to it whenever one lands.",
  ),
  ProgramTask(
    day: 59,
    title: "Three Words for Future You",
    opener: "Not who you were with them. Not who you are today, mid-healing. Who is the person walking out the other side of this?",
    action: "Journal: 'The person I'm becoming is ___, ___, and ___.' Three adjectives. Then one line: what's one thing that person does?",
  ),
  ProgramTask(
    day: 60,
    title: "Sixty Days of Proof",
    opener: "Two months. Read that again: two months. Whatever today feels like, you have sixty days of proof that you can do hard things.",
    action: "Scroll your streak and journal back to Day 30. Write one line: 'Between Day 30 and Day 60, I ___.' That's your evidence.",
  ),
  ProgramTask(
    day: 61,
    title: "The One-Sentence Story",
    opener: "You've been telling the long version — the play-by-play, the what-ifs. The short version is where the power is.",
    action: "Write your story in ONE sentence: 'We loved each other, it ended, and I'm rebuilding.' Say it out loud. That's the whole story now.",
  ),
  ProgramTask(
    day: 62,
    title: "Forgive Your Old Self",
    opener: "You've been prosecuting the person you were in that relationship — for staying, for missing red flags, for not knowing. Court is adjourned.",
    action: "Write: 'Dear me back then — you did the best you could with what you knew. I forgive you.' Read it twice. Mean it once.",
  ),
  ProgramTask(
    day: 63,
    title: "Start a Weekly Ritual",
    opener: "Healing needs rhythm, not just willpower. One repeating ritual can hold you steadier than a hundred good intentions.",
    action: "Pick ONE weekly ritual — Sunday walk, Friday journal, Wednesday call with a friend. Put it in your calendar right now, recurring.",
  ),
  ProgramTask(
    day: 64,
    title: "Read an Old Letter",
    opener: "Somewhere in your vault is a letter from the rawest days. You're strong enough now to visit it — as a visitor, not a resident.",
    action: "Open the letter vault and re-read ONE early letter. Notice what you feel now versus then. Write one line about the distance traveled.",
  ),
  ProgramTask(
    day: 65,
    title: "The Dating Question",
    opener: "Someone will ask soon — maybe already has. There's no deadline on this, and 'not yet' is a complete, respectable answer.",
    action: "Journal honestly: 'Am I ready to date? ___ because ___.' No wrong answer. Whatever you wrote — trust it for now.",
  ),
  ProgramTask(
    day: 66,
    title: "Three Specific Gratitudes",
    opener: "Not poster-gratitude. The small, weird, specific kind that proves you're actually noticing your life again.",
    action: "Write 3 specific gratitudes: the barista's foam art, the text from your sister, the song at the red light. Tiny. Real.",
  ),
  ProgramTask(
    day: 67,
    title: "What Would You Tell a Friend?",
    opener: "You give better advice than you take — everyone does. Borrow your own wisdom for two minutes.",
    action: "Imagine your best friend going through exactly this. Write the 3 sentences you'd say to them. Now read them as if they're for you.",
  ),
  ProgramTask(
    day: 68,
    title: "Slipping at Day 68 Is Human",
    opener: "If you reached out this week — after all these days — you're probably furious with yourself. Don't be. Sixty-eight days of healing doesn't vanish in one message.",
    action: "Write what happened and what triggered it — just facts. Then write: 'The days I showed up for myself: still mine.' Because they are.",
  ),
  ProgramTask(
    day: 69,
    title: "One Promise to Your Body",
    opener: "Your body carried you through the worst of this without quitting. It's earned more than survival mode — it's earned a promise.",
    action: "Make ONE small body promise: a daily walk, water before coffee, bedtime by midnight. Write it down. Start tomorrow.",
  ),
  ProgramTask(
    day: 70,
    title: "The Two-Minute Dream",
    opener: "For weeks the future was a blank wall. Today, let's paint one small corner of it — not the whole mural, just a corner.",
    action: "Set a timer for 2 minutes and write everything you'd do with a completely free Saturday a year from now. Don't edit. Dream on paper.",
  ),
  ProgramTask(
    day: 71,
    title: "Decide About Their Socials",
    opener: "Muted, blocked, still watching — whatever you chose on Day 9 was for survival. Today's choice can be for the long term.",
    action: "Make a conscious decision: keep them muted, unfollow, or block — deliberately, for the long term. Do it now. Write why in one line.",
  ),
  ProgramTask(
    day: 72,
    title: "The Apology You Owe Yourself",
    opener: "You've apologized to everyone — maybe even to them, in your head, for things that weren't yours. One apology is still outstanding.",
    action: "Write: 'I'm sorry I ___ (neglected you, spoke cruelly to you, put you last). You deserved better from me.' Sign it with your name.",
  ),
  ProgramTask(
    day: 73,
    title: "One Small Kindness Outward",
    opener: "Healing turns inward for a long time — necessarily. But a little outward kindness is proof the heart still works both ways.",
    action: "Do one tiny kind thing for a stranger or friend: hold a door, send a compliment text, buy the coffee. Two minutes. Notice the warmth.",
  ),
  ProgramTask(
    day: 74,
    title: "Build the New Playlist",
    opener: "Your old playlist is a museum. Time to open a new wing — songs that belong to the person you're becoming, not the one you were.",
    action: "Create a new playlist called something hopeful. Add 3 songs that feel like forward. Play it while you do something you enjoy.",
  ),
  ProgramTask(
    day: 75,
    title: "Make Home Yours Again",
    opener: "Home used to mean 'us.' Now it gets to mean 'me' — every corner, every ritual, every quiet evening exactly how you like it.",
    action: "Change one thing in your home tonight: light a candle at dinner, move your chair to the window, buy the flowers. Make it yours.",
  ),
  ProgramTask(
    day: 76,
    title: "Pick One Skill to Grow",
    opener: "The most attractive thing in the world is a person becoming more themselves. Pick one skill and start becoming.",
    action: "Choose ONE skill to grow over the next 30 days — cooking, a language, an instrument, a craft. Find a beginner lesson and do the first 2 minutes today.",
  ),
  ProgramTask(
    day: 77,
    title: "Old Photos, New Eyes",
    opener: "There are photos from the good times that still sting. Today, look at one — not to reopen the wound, but to check if it's still bleeding.",
    action: "Look at one old happy photo for 60 seconds. Notice: does it still undo you, or can you see a person who was happy and will be again? Write one line.",
  ),
  ProgramTask(
    day: 78,
    title: "The Never-Again List",
    opener: "Not bitterness — boundaries. The clearest gift of a hard ending is knowing exactly what you will not accept next time.",
    action: "Write 3 things you will not accept in your next relationship — specific, not vague. This list is wisdom, not walls.",
  ),
  ProgramTask(
    day: 79,
    title: "Write the Last Line",
    opener: "Every story needs a last line. Not the ending you wanted — the ending you're writing now, with your own hand.",
    action: "Journal: write the final line of this chapter. Something like: 'And then I chose myself.' Read it out loud. Mean it.",
  ),
  ProgramTask(
    day: 80,
    title: "Ten Good Things About Now",
    opener: "Eighty days ago, 'good things' felt like a foreign language. Let's check your fluency.",
    action: "Number 1-10 and list ten good things about your life right now — people, moments, small comforts. If you stall at 6, keep going. Ten.",
  ),
  ProgramTask(
    day: 81,
    title: "One Bigger Brave",
    opener: "You've done small brave things for weeks. The muscle is built. Time for one rep with a little more weight.",
    action: "Do one bigger brave thing: apply for the thing, book the trip, have the conversation, go alone to the event. Write what you chose.",
  ),
  ProgramTask(
    day: 82,
    title: "The Goodbye Letter",
    opener: "Not to send — to finish. Some things need to be said to be released, even if the only ears are your own.",
    action: "In the letter vault, write the goodbye letter: what you loved, what hurt, what you release. Seal it. This one is the period at the end.",
  ),
  ProgramTask(
    day: 83,
    title: "Who Showed Up?",
    opener: "Hard times are a strange gift: they show you exactly who your people are. Look around at who's still standing beside you.",
    action: "List the people who showed up during these 90 days — texts, calls, coffees. Send one of them a thank-you today. Two sentences.",
  ),
  ProgramTask(
    day: 84,
    title: "Describe Your Ideal Morning",
    opener: "The mornings used to belong to grief. Now they belong to you — so what does a good one actually look like?",
    action: "Write your ideal morning in 5 lines: what time, what you drink, what you do, how it feels. Do one line of it tomorrow.",
  ),
  ProgramTask(
    day: 85,
    title: "Three Honest Lessons",
    opener: "Not the poster kind. The real kind — the ones that cost you something to learn.",
    action: "Write 3 honest lessons from this relationship and its ending. No bitterness, no empty slogans — just true. These are yours forever.",
  ),
  ProgramTask(
    day: 86,
    title: "Letter to Day 365",
    opener: "Ninety days felt impossible once. A year from now is just the same trick, repeated. Leave that future person a map.",
    action: "In the letter vault, write to your Day 365 self: where you are now, what you hope, what you want them to remember. Seal it with care.",
  ),
  ProgramTask(
    day: 87,
    title: "Celebrate on Purpose",
    opener: "You've been waiting to feel 'done' before celebrating. Don't wait. Celebrate the becoming — that's the whole point.",
    action: "Do one celebratory thing today, deliberately: the nice dinner, the dessert, the toast (to yourself). Say out loud what you're celebrating.",
  ),
  ProgramTask(
    day: 88,
    title: "Measure the Distance",
    opener: "You can't feel growth while you're inside it — like not noticing your hair grow. Let's measure.",
    action: "Re-read your Day 1 and Day 2 journal entries. Then write: 'The biggest difference between then and now is ___.' Sit with that.",
  ),
  ProgramTask(
    day: 89,
    title: "Prepare Your Day 90",
    opener: "Tomorrow is Day 90 — not a finish line, a doorway. Doorways deserve a little ceremony.",
    action: "Plan one small Day-90 ritual: a sunrise walk, a favorite meal, re-reading your Day 50 letter. Write the plan down tonight.",
  ),
  ProgramTask(
    day: 90,
    title: "Day One, Again",
    opener: "Ninety days ago you could barely breathe through an hour. Look at you now — still standing, still becoming. This was never about getting over them. It was about getting back to you.",
    action: "Write your Day One sentence — the line this whole journey was building toward. Something like: 'I am mine again.' Then begin.",
  ),
];
