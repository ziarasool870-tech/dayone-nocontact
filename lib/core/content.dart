/// Static content pack for Day One: No Contact.
/// All local, zero network cost. Warm, non-clinical tone.
/// Never makes therapeutic claims — this is a self-care companion.
library;

/// 30 rotating daily healing quotes. Rotation: dayOfYear % quotes.length.
const List<String> healingQuotes = [
  "Healing isn't linear. Bad days don't erase good ones.",
  "You don't miss them. You miss who you were when you felt chosen.",
  "No contact isn't punishment. It's protection.",
  "The urge to text is a wave. Waves always pass.",
  "You're not starting over. You're starting wiser.",
  "Missing someone is not a reason to call them.",
  "Choose the future you over the past you.",
  "Silence is also an answer — the kindest one you can give yourself.",
  "Day by day, the ache gets quieter. Trust the process.",
  "You survived every hard day so far. That's a 100% record.",
  "Don't reopen a door you worked this hard to close.",
  "Your peace is worth more than their reply.",
  "Growth looks like not sending the text.",
  "Let them wonder. You keep walking.",
  "The right person won't need to be chased, convinced, or waited for.",
  "Nostalgia lies. Remember why you left.",
  "You're allowed to miss them and still choose yourself.",
  "One day this will be a story about how strong you became.",
  "Protect your progress like it's precious. It is.",
  "Loneliness is temporary. Regret from breaking no contact lasts longer.",
  "You are not hard to love. You were loving the wrong person hard.",
  "Every day you don't reach out, you reach inward.",
  "The block button is self-care in its purest form.",
  "Cry if you need to. Then keep going.",
  "Their silence taught you what their words never could.",
  "You're not behind. You're becoming.",
  "A clean break heals faster than a slow bleed.",
  "Your future self is thanking you right now.",
  "Strength isn't never falling. It's restarting at Day 0 without shame.",
  "One day, you'll be grateful you didn't send that text.",
];

/// Default "read my reasons" list shown in the SOS flow.
/// Users can edit these in a later version; v1 ships these defaults.
const List<String> defaultReasons = [
  "I deserve someone who chooses me every day.",
  "Breaking contact resets my healing to zero.",
  "I already know how that conversation ends.",
  "My peace took weeks to build. One text can break it.",
  "I am becoming someone who doesn't beg for love.",
];

/// Distraction suggestions shown in the SOS flow.
const List<String> distractionIdeas = [
  "Text a friend instead — tell them one good thing about today.",
  "Put on your power playlist and walk around the block.",
  "Write the text in your journal. Don't send it.",
  "Splash cold water on your face. Take 10 slow breaths.",
  "Do 20 pushups. Move the feeling through your body.",
  "Make your bed, make tea, make a plan for tomorrow.",
];

/// "Why no contact works" — framed as commonly shared self-care advice,
/// never as medical or therapeutic claims.
const List<Map<String, String>> whyNoContactWorks = [
  {
    "title": "It breaks the habit loop",
    "body":
        "Checking their profile or rereading old chats trains your brain to crave the next hit. Distance starves the loop until it fades.",
  },
  {
    "title": "It stops reopening the wound",
    "body":
        "Every 'just checking in' text restarts the cycle of hope and disappointment. Silence lets the cut actually close.",
  },
  {
    "title": "It gives you your identity back",
    "body":
        "Relationships shape your routines, tastes, even your humor. Space lets you remember who you are without them.",
  },
  {
    "title": "It protects your dignity",
    "body":
        "Chasing someone who left rarely brings them back — but it almost always costs you self-respect. Walking away keeps it.",
  },
];

/// Displayed on SOS-adjacent screens and in Profile. Never a substitute claim.
const String disclaimerText =
    "Day One is a self-care companion, not a therapist. It can't replace "
    "professional support. If you're struggling, please reach out to someone "
    "you trust — or a crisis line below.";

const String crisisUs = "US: call or text 988";
const String crisisUk = "UK: Samaritans 116 123";

/// Milestone days for unlock logic. Single source of truth.
const List<int> milestoneDays = [7, 14, 30, 60, 90];

/// Relapse copy — shame-free by design.
const String relapseTitle = "It's okay.";
const String relapseBody =
    "Most people restart twice before it sticks. "
    "Your longest streak and every journal entry stay with you — "
    "only the counter starts fresh. Day 0 again. You've got this.";
