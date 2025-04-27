import express from 'express';
import { OpenAI } from 'openai'; // Use the compatible OpenAI SDK
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

// Load environment variables from .env file
dotenv.config();

// Required for __dirname in ES Modules
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const port = process.env.PORT || 3000; // Use port 3000 or environment variable

// Middleware to parse JSON request bodies
app.use(express.json());

// Serve static files from the 'public' directory
app.use(express.static(path.join(__dirname, 'public')));

// --- OpenRouter Configuration ---
const openrouterApiKey = process.env.OPENROUTER_API_KEY;

if (!openrouterApiKey) {
    console.error("Error: OPENROUTER_API_KEY not found in .env file or environment variables.");
    console.error("Please set OPENROUTER_API_KEY to your OpenRouter API key.");
    process.exit(1); // Exit if API key is not set
}

const openai = new OpenAI({ // Use OpenAI SDK pointing to OpenRouter
    baseURL: "https://openrouter.ai/api/v1",
    apiKey: openrouterApiKey,
    // Optional: Add custom headers for OpenRouter rankings
    defaultHeaders: {
        "HTTP-Referer": "http://localhost:3000", // Set for local testing/direct access. Change for public deployment.
        "X-Title": "Your App Name Here",     // Replace with your app name for rankings
    },
});

// --- API Endpoint to handle prompt ---
app.post('/generate', async (req, res) => {
    const userPrompt = req.body.prompt;

    if (!userPrompt) {
        return res.status(400).json({ error: { message: 'Prompt is required in the request body.' } });
    }

    console.log(`Received prompt: "${userPrompt}"`);

    try {
        // Use the specified model with the thinking variant
        const completion = await openai.chat.completions.create({
            model: 'google/gemini-2.5-flash-preview:thinking',
            messages: [
                { role: "user", content: userPrompt },
            ],
            // Optional: Add other parameters if needed (e.g., max_tokens, temperature)
            // max_tokens: 500,
            // temperature: 0.7,
             reasoning: { include: true } // Explicitly include reasoning if you want it
        });

        // The response structure might vary slightly depending on the model and options
        // Let's try to get content or reasoning if available
        const aiResponseContent = completion.choices[0]?.message?.content;
        const aiReasoning = completion.choices[0]?.message?.reasoning;

        let responseToSend = "";

        if (aiReasoning) {
            responseToSend += "Reasoning:\n---\n" + aiReasoning + "\n\n";
        }

        if (aiResponseContent) {
             responseToSend += "Content:\n---\n" + aiResponseContent;
        }

        // If neither content nor reasoning, something unexpected happened
        if (!responseToSend) {
             console.error("OpenRouter response did not contain content or reasoning:", completion);
             return res.status(500).json({ error: { message: 'OpenRouter returned an empty response.' } });
        }


        console.log("Generated response successfully.");

        res.json({ response: responseToSend }); // Send the combined response back to the frontend

    } catch (error) {
        console.error('Error calling OpenRouter API:', error);
        // Attempt to extract a more specific error message if available
        const errorMessage = error.response?.data?.error?.message || error.message || 'An unexpected error occurred.';
        res.status(error.status || 500).json({ error: { message: `API Error: ${errorMessage}` } });
    }
});

// --- Start the server ---
app.listen(port, () => {
    console.log(`Server listening on port ${port}`);
    console.log(`Serving static files from: ${path.join(__dirname, 'public')}`);
    console.log(`Access the app at http://localhost:${port} (or your VPS IP)`);
});
