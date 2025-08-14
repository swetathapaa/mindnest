const express = require('express');
const cors = require('cors');
const { OpenAI } = require('openai');

const app = express();
const port = 3000;

app.use(cors());
app.use(express.json());

// === CONFIGURE YOUR API KEYS HERE ===
const OPENROUTER_API_KEY = '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';

// === OPENROUTER CLIENT ===
const openai = new OpenAI({
  apiKey: OPENROUTER_API_KEY,
  baseURL: 'https://openrouter.ai/api/v1',
});

app.post('/getMoodResponse', async (req, res) => {
  try {
    const { moods, journal } = req.body;

    if (!moods || !Array.isArray(moods) || moods.length === 0) {
      return res.status(400).json({ error: 'Moods are required.' });
    }

    // Build an empathetic, structured prompt for the AI
    const prompt = `You are an empathetic and supportive AI assistant.
Based on the user's moods and journal entry, provide helpful emotional insights and music that can lift their spirits.

User moods: ${moods.join(', ')}.
${journal && journal.trim().length > 0 ? `User journal: ${journal}` : ''}

Respond ONLY in valid JSON with the following structure:
{
  "summary": "Briefly summarize how the user might be feeling, in a warm and caring tone.",
  "reflection": "Give a gentle reflection to help them understand their emotions better.",
  "action": "Suggest a small, practical step they can take right now to feel better.",
  "songs": [
    { "title": "Song 1 title", "artist": "Artist 1", "youtubeLink": "https://..." },
    { "title": "Song 2 title", "artist": "Artist 2", "youtubeLink": "https://..." }
  ]
}

Rules:
- YouTube links must be valid search URLs or direct video links.
- Songs should fit the emotional tone (uplifting if sad, calming if anxious, energizing if tired).
- Keep the tone warm and supportive.
`;

    // Call OpenRouter / GPT model
    const response = await openai.chat.completions.create({
      model: 'gpt-4o-mini',
      messages: [{ role: 'user', content: prompt }],
      max_tokens: 500,
    });

    const raw = response.choices?.[0]?.message?.content?.trim() || '';

    let parsed;
    try {
      parsed = JSON.parse(raw);
    } catch (e) {
      const match = raw.match(/\{[\s\S]*\}/);
      if (match) {
        try {
          parsed = JSON.parse(match[0]);
        } catch (_) {
          parsed = null;
        }
      }
    }

    if (parsed) {
      return res.status(200).json(parsed);
    }

    return res.status(500).json({ error: 'Could not parse AI response.' });
  } catch (error) {
    console.error('AI backend error:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

app.listen(port, () => {
  console.log(`Local server listening at http://localhost:${port}`);
});
