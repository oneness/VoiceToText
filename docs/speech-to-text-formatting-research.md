# Speech-to-Text Models with Formatting Capabilities - Research 2026

> **Research Date:** February 5, 2026
> **Purpose:** Find speech-to-text models that can transcribe AND format text in one API call based on spoken instructions

---

## Executive Summary

**Goal:** Transcribe speech AND format/rewrite based on instructions - all in ONE step.

**Finding:** **GPT-4o-transcribe** and **Gemini 2.0** support transcription with formatting instructions via a text prompt parameter. However, the ability to detect and follow **spoken commands embedded IN the audio** is unconfirmed and requires testing.

**Current Project Setup:** Groq API using `whisper-large-v3-turbo` (transcription only, no formatting).

---

## Current Setup Analysis

### What You Have Now

**Model:** `whisper-large-v3-turbo` via Groq API
**Location:** `VoiceToText/Managers/GroqTranscriber.swift:45`

```swift
body.append("whisper-large-v3-turbo".data(using: .utf8)!)
```

**What Whisper Does:**
- ✅ Transcribes speech to text (verbatim)
- ✅ Fast (turbo variant)
- ✅ Multi-language support
- ❌ Does NOT rewrite or format text
- ❌ Does NOT follow instructions
- ❌ Does NOT improve coherence or writing style

**Example:**
```
You speak: "Um, so like, I was thinking maybe we could do this thing and it would be cool"
Whisper returns: "Um, so like, I was thinking maybe we could do this thing and it would be cool"
```

**What Whisper CANNOT Do:**
- ❌ "Make this native English"
- ❌ "Format as professional email"
- ❌ "Rewrite more coherently"
- ❌ "Extract action items"

---

## Models That Support Transcription + Formatting

### 1. GPT-4o-transcribe (OpenAI) ⭐ **Recommended**

**API Usage:**
```python
response = openai.audio.transcriptions.create(
    model="gpt-4o-transcribe",
    file=audio_file,
    prompt="Format as a professional email with subject line, salutation, and sign-off"
)
```

**Features:**
- ✅ Transcribes audio
- ✅ Follows formatting instructions in `prompt` parameter
- ✅ Higher quality than Whisper
- ✅ Real-time transcription via WebSocket
- ✅ 128K token context window
- ✅ Supports custom formatting, summarization, rewriting

**Example Prompts:**
```
"Format as a professional email with subject line, salutation, and sign-off"
"Summarize into 3 bullet points"
"Extract action items as a numbered task list"
"Rewrite in formal business tone"
"Convert to markdown with headers"
```

**If No Prompt Provided:**
- Returns raw transcription

**Pricing:** Available via OpenAI API

**Documentation:**
- [OpenAI Speech to Text](https://platform.openai.com/docs/guides/speech-to-text)
- [Next-generation audio models](https://openai.com/index/introducing-our-next-generation-audio-models/)

---

### 2. Gemini 2.0 Flash/Pro (Google)

**API Usage:**
```python
response = genai.generate_content(
    model="gemini-2.0-flash",
    contents=[
        "Transcribe this audio and format as a professional email",
        audio_blob
    ]
)
```

**Features:**
- ✅ Native audio understanding
- ✅ Follows formatting instructions
- ✅ Speaker diarization (labels who spoke)
- ✅ Timestamps (to the second)
- ✅ 1M-2M token context window (massive!)
- ✅ Multimodal (video + audio)
- ✅ Translation during transcription

**Advantages over GPT-4o:**
- Larger context window (1M vs 128K tokens)
- Built-in speaker labeling
- Can reference sample formats

**Documentation:**
- [Gemini Audio Understanding](https://ai.google.dev/gemini-api/docs/audio)
- [Gemini 2.0 Flash Docs](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/models/gemini/2-0-flash)

---

## Option B: Spoken Commands IN Audio - Status

### What You Want

```
You speak: "Format as email. Here are my meeting notes from today..."
Model detects: "Format as email" instruction
Model returns: Well-formatted email
```

### Reality Check

**❌ NOT Confirmed by Documentation**

Neither GPT-4o-transcribe nor Gemini 2.0 documentation explicitly confirms they can:
- Detect spoken commands embedded IN the audio
- Parse those commands from the transcription
- Apply formatting based on spoken instructions

**The prompt parameter is:**
- A **separate text field** sent with the API call
- Set in code, not spoken

**Uncertainty:**
- These models MIGHT understand spoken commands (they're smart)
- But this needs **actual testing** to verify
- Not guaranteed by documentation

---

## Implementation Options

### Option A: Pre-Set Prompt (Before Recording) ⭐ **Confirmed to Work**

**Workflow:**
```
1. User selects format in menu/app:
   - 📧 Email format
   - ✅ Bullet points
   - 👔 Formal tone
   - 📝 Markdown

2. App sets prompt parameter accordingly

3. User records audio

4. API call: audio + prompt

5. Returns formatted transcription directly
```

**Implementation:**
```swift
// Pseudocode
let formatPrompts = [
    "email": "Format as a professional email with subject line, salutation, and sign-off",
    "bullets": "Summarize into bullet points",
    "formal": "Rewrite in formal business tone with proper structure"
]

func transcribe(audioURL: URL, format: String) {
    let prompt = formatPrompts[format]
    // Send to API with audio + prompt
}
```

**Pros:**
- ✅ Confirmed to work
- ✅ One API call
- ✅ Simple to implement
- ✅ User knows format upfront

---

### Option B: Post-Recording Menu (Confirmed to Work)

**Workflow:**
```
1. Record raw audio (no format specified)
2. Transcription completes
3. Menu pops up: "Format as:"
   - Email
   - Bullet points
   - Formal tone
   - Markdown
4. User selects format
5. Send transcription + format instruction to API
6. Returns formatted version
7. Auto-paste formatted result
```

**Pros:**
- ✅ Confirmed to work
- ✅ Flexible - choose after recording
- ✅ Can see raw version first
- ✅ Try multiple formats

---

### Option C: Two-Step Process (Current Groq + Groq LLM)

**Workflow:**
```
Step 1: Whisper transcribes (your current setup)
Step 2: Send to Groq LLM with formatting instructions
```

**Groq LLM Options:**
- `llama-3.3-70b-versatile`
- `mixtral-8x7b-instruct`
- `gemma2-9b-it`

**Implementation:**
```swift
// Step 1: Transcribe with Whisper
let transcription = GroqTranscriber.shared.transcribe(audioURL)

// Step 2: Format with LLM
let formatted = GroqLLM.shared.format(
    transcription,
    instruction: "Rewrite as professional email"
)
```

**Pros:**
- ✅ Uses Groq (already set up)
- ✅ Flexible LLM options
- ✅ Fast inference

**Cons:**
- ❌ Two API calls
- ❌ More complex

---

## Comparison Table

| Feature | Whisper (current) | GPT-4o-transcribe | Gemini 2.0 |
|---------|-------------------|-------------------|--------------|
| **Transcription** | ✅ | ✅ | ✅ |
| **Formatting Instructions** | ❌ | ✅ (via prompt param) | ✅ (via prompt param) |
| **One API Call** | ✅ | ✅ | ✅ |
| **Speaker Diarization** | ❌ | Available | ✅ Built-in |
| **Context Window** | - | 128K tokens | 1M-2M tokens |
| **Speed** | ⚡ Turbo (fast) | Fast | Fast |
| **Current Setup** | ✅ | ❌ | ❌ |
| **Cost** | Free (Groq) | Paid API | Free tier available |

---

## Recommendations

### For Your Project

**Option 1: Quick Win (Add Formatting Layer)**
```
Keep: Whisper via Groq (transcription)
Add: Groq LLM call for formatting
Benefit: Uses existing infrastructure
Complexity: Low
```

**Option 2: Switch to GPT-4o-transcribe**
```
Replace: Whisper → GPT-4o-transcribe
Benefit: One API call for everything
Complexity: Medium (API switch)
```

**Option 3: Pre-Set Format Menu**
```
Add: Menu with format options
Keep: Whisper or switch to GPT-4o
Benefit: User control over output
Complexity: Low-Medium
```

---

## Key Takeaways

1. **Whisper = Transcription only** - it does NOT rewrite or format text
2. **For "smart" formatting** you need an LLM (GPT-4o, Gemini, Groq LLMs)
3. **GPT-4o-transcribe and Gemini 2.0** can do both in ONE call
4. **Spoken commands IN audio** = Not confirmed, needs testing
5. **Easiest path:** Add formatting step with Groq LLM or switch to GPT-4o-transcribe

---

## Sources

- [OpenAI Speech to Text Documentation](https://platform.openai.com/docs/guides/speech-to-text)
- [Introducing next-generation audio models](https://openai.com/index/introducing-our-next-generation-audio-models/)
- [Gemini Audio Understanding Documentation](https://ai.google.dev/gemini-api/docs/audio)
- [Gemini 2.0 Flash Documentation](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/models/gemini/2-0-flash)
- [Real-time Speech Transcription with GPT-4o-transcribe](https://techcommunity.microsoft.com/blog/azure-ai-foundry-blog/real-time-speech-transcription-with-gpt-4o-transcribe-and-gpt-4o-mini-transcribe/4410353)
- [Best open source speech-to-text models 2026](https://www.gladia.io/blog/best-open-source-speech-to-text-models)
- [A practical guide to OpenAI audio transcription](https://www.eesel.ai/blog/openai-audio-transcription)

---

## Notes for Future Implementation

### When ready to implement formatting feature:

1. **Decide on approach:**
   - Add Groq LLM formatting step (uses existing Groq account)
   - Switch to GPT-4o-transcribe (need OpenAI API key)
   - Switch to Gemini 2.0 (need Google API key)

2. **Test spoken command approach:**
   - Record: "Format as email. Here are my ideas..."
   - Send to GPT-4o-transcribe or Gemini 2.0
   - Check if it detects and follows the command

3. **UI considerations:**
   - Format menu (pre-set or post-recording)
   - Visual feedback for selected format
   - Fallback to raw transcription if formatting fails

---

## ⚡ SPEED OPTIMIZATION RESEARCH

**Goal:** Find the fastest speech-to-text models for minimal latency

---

### **SPEED CHAMPIONS** (Ranked by RTFx - Real-Time Factor)

**RTFx Meaning:** How many seconds of audio processed per 1 second of compute time (higher = faster)

| Model | RTFx | WER | Size | Language | VRAM | License |
|-------|------|-----|------|----------|------|----------|
| **🥇 Parakeet TDT 1.1B** | **>2,000x** 🔥 | ~8.0% | 1.1B | English | ~4GB | CC-BY-4.0 |
| **🥈 Canary Qwen 2.5B** | **418x** | 5.63% | 2.5B | English | ~8GB | CC-BY-4.0 |
| **🥉 Whisper Large V3 Turbo** | **216x** | 7.75% | 809M | 99+ | ~6GB | MIT |
| **4th: Distil-Whisper** | **~120x** | Within 1% of Large V3 | 756M | English | ~5GB | MIT |

---

### **COMMERCIAL API Latency Comparison**

| Service | Latency | Notes |
|---------|---------|-------|
| **Mistral Voxtral Transcribe 2** | **<200ms** | Fastest streaming |
| **Gladia Solaria** | ~270ms | Very fast |
| **Deepgram Nova-3** | <300ms | Sub-300ms latency |
| **GPT-4o-transcribe** | ~320ms | 100+ languages |

---

### **YOUR CURRENT SETUP: Already Optimized!** ✅

**Current:** Groq + Whisper-Large-V3-Turbo
- **RTFx:** 216x (excellent!)
- **WER:** 7.75%
- **Languages:** 99+
- **Expected Total Time:** 1-2 seconds

**Breakdown:**
- Audio upload: 0.5-1s (network dependent)
- Transcription: 0.5-1.5s (Groq turbo model)
- Journal save: <0.1s (local file I/O)

**Conclusion:** You're already using one of the fastest models that balances speed + accuracy!

---

### **Why NOT to Switch to Parakeet TDT or Canary Qwen**

**Speed champions sacrifice accuracy for speed:**
- Parakeet TDT: 8.0% WER (worse than your 7.75%)
- Canary Qwen: 5.63% WER (slightly better, but English only)

**Your setup advantages:**
- ✅ Multilingual (99+ languages)
- ✅ Great accuracy
- ✅ Fast enough (1-2 seconds)
- ✅ Already deployed

---

### **Performance Benchmarking Ideas**

**Simple implementation:**
```swift
let startTime = Date()

// Upload
let uploadStart = Date()
// ... upload ...
let uploadTime = Date().timeIntervalSince(uploadStart)

// Transcribe
let transcribeStart = Date()
// ... transcribe ...
let transcribeTime = Date().timeIntervalSince(transcribeStart)

// Save to journal
let journalStart = Date()
// ... save ...
let journalTime = Date().timeIntervalSince(journalStart)

let totalTime = Date().timeIntervalSince(startTime)

print("=== PERFORMANCE ===")
print("Upload: \(String(format: "%.2f", uploadTime))s")
print("Transcribe: \(String(format: "%.2f", transcribeTime))s")
print("Journal: \(String(format: "%.2f", journalTime))s")
print("Total: \(String(format: "%.2f", totalTime))s")
```

**Expected output:**
```
=== PERFORMANCE ===
Upload: 0.82s
Transcribe: 1.15s
Journal: 0.04s
Total: 2.01s
```

---

### **Speed Optimization Takeaways**

**Current bottlenecks (in order):**
1. **Network upload** - Depends on file size + connection speed
2. **Groq queue processing** - API server load
3. **Model inference** - Very fast on Groq infrastructure

**Already optimized:**
- ✅ Using turbo model (Whisper Large V3 Turbo)
- ✅ Audio at 16kHz (Whisper's native rate)
- ✅ Medium quality audio (smaller files)
- ✅ One of the fastest models available

---

**Last Updated:** February 5, 2026
**Status:** Research complete, ready for implementation when needed
