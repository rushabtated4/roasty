import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};
function getSystemPrompt(tone) {
  switch(tone){
    case 'motivational':
      return `You are an enthusiastic and supportive coach who believes in everyone's potential. 
Your role is to generate motivational messages that inspire and encourage while maintaining a touch of playful humor. 
Never be harsh or negative - focus on growth, potential, and the power of persistence.
Generate responses as a JSON array only. Each object should have keys "screen", "done", "missed".`;
    case 'mild':
      return `You are a friendly but slightly sarcastic coach with a good sense of humor. 
Your role is to generate light-hearted teasing messages that motivate through gentle ribbing and playful jokes.
Keep the tone fun and engaging without being too harsh.
Generate responses as a JSON array only. Each object should have keys "screen", "done", "missed".`;
    case 'medium':
      return `You are a tough-love coach who doesn't accept excuses but still maintains humor.
Your role is to generate messages that combine stronger criticism with dark humor and sarcasm.
Be more pointed in your criticism while keeping it entertaining and motivating.
Generate responses as a JSON array only. Each object should have keys "screen", "done", "missed".`;
    case 'brutal':
      return `You are a ruthlessly honest roast master with a dark sense of humor.
Your role is to generate brutal, unfiltered roasts that use harsh criticism, foul language, and dark humor.
Don't hold back - be savage while still being funny. Make them feel both called out and entertained.
Generate responses as a JSON array only. Each object should have keys "screen", "done", "missed".`;
    default:
      return `You are a dark-humour roast generator which can make user cry, use foul words as well.
Generate responses as a JSON array only. Each object should have keys "screen", "done", "missed".`;
  }
}
function buildPrompt(request) {
  const { habit, reason, tone, streak, consecutiveMisses, escalationState, count = 7 } = request;
  return `Generate ${count} JSON objects with keys "screen", "done", "missed".
tone="${tone}" (motivational|mild|medium|brutal)
escalation_state=${escalationState}
consecutive_misses=${consecutiveMisses}
streak=${streak}
habit="${habit}" because "${reason}"

Return ONLY a JSON object with a "roasts" array containing the objects. For example:
{
  "roasts": [
    {
      "screen": "<roast message>",
      "done": "<done message, again a roast>",
      "missed": "<missed message again a roast>"
    }
  ]
}`;
}
function generateDummyRoasts(tone, count) {
  const baseRoasts = {
    'motivational': [
      {
        screen: 'You\'ve got this! Time to make today count.',
        done: 'Amazing work! You\'re building something incredible.',
        missed: 'Tomorrow is a fresh start. Don\'t give up on yourself.'
      },
      {
        screen: 'Your future self is counting on today\'s choices.',
        done: 'That\'s the spirit! Keep pushing forward.',
        missed: 'Setbacks are setups for comebacks. Keep going.'
      }
    ],
    'mild': [
      {
        screen: 'Well, well... are we doing this today or what?',
        done: 'Look who decided to show up! Not bad.',
        missed: 'Seriously? We had ONE job today.'
      },
      {
        screen: 'Time to put your money where your mouth is.',
        done: 'Finally! Was starting to worry about you.',
        missed: 'Another day, another creative excuse.'
      }
    ],
    'medium': [
      {
        screen: 'Time to stop being a disappointment to yourself.',
        done: 'Wow, you actually did it. Color me shocked.',
        missed: 'Pathetic. Your excuses are getting weaker.'
      },
      {
        screen: 'Let\'s see if you can actually follow through today.',
        done: 'Incredible! You managed basic human consistency.',
        missed: 'Another failed promise to yourself. Shocking.'
      }
    ],
    'brutal': [
      {
        screen: 'Time to prove you\'re not completely useless.',
        done: 'Holy crap, you actually did something right for once.',
        missed: 'Absolutely pathetic. You\'re your own worst enemy.'
      },
      {
        screen: 'Let\'s see how spectacularly you fail today.',
        done: 'Miracles do happen. You didn\'t screw up today.',
        missed: 'Congratulations, you\'ve mastered the art of failure.'
      }
    ]
  };
  const roastList = baseRoasts[tone] || baseRoasts['mild'];
  const result = [];
  for(let i = 0; i < count; i++){
    result.push(roastList[i % roastList.length]);
  }
  return result;
}
async function generateRoasts(request) {
  const openaiApiKey = Deno.env.get('OPENAI_API_KEY');
  if (!openaiApiKey) {
    console.error('OPENAI_API_KEY environment variable not set');
    return generateDummyRoasts(request.tone, request.count || 7);
  }
  try {
    const prompt = buildPrompt(request);
    const systemPrompt = getSystemPrompt(request.tone);
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${openaiApiKey}`
      },
      body: JSON.stringify({
        model: 'gpt-4o',
        messages: [
          {
            role: 'system',
            content: systemPrompt
          },
          {
            role: 'user',
            content: prompt
          }
        ],
        response_format: {
          type: 'json_object'
        },
        max_tokens: 2000,
        temperature: 0.8
      })
    });
    if (!response.ok) {
      throw new Error(`OpenAI API request failed: ${response.status}`);
    }
    const data = await response.json();
    const content = data.choices[0].message.content;
    // Parse the JSON response
    try {
      const roastsJson = JSON.parse(content);
      // Handle both array and object with array property
      let roastsList;
      if (Array.isArray(roastsJson)) {
        roastsList = roastsJson;
      } else if (roastsJson && roastsJson.roasts && Array.isArray(roastsJson.roasts)) {
        roastsList = roastsJson.roasts;
      } else {
        throw new Error('Invalid JSON structure');
      }
      return roastsList.map((roast)=>({
          screen: roast.screen || '',
          done: roast.done || '',
          missed: roast.missed || ''
        }));
    } catch (e) {
      console.error('JSON parsing failed:', e);
      return generateDummyRoasts(request.tone, request.count || 7);
    }
  } catch (error) {
    console.error('OpenAI API error:', error);
    return generateDummyRoasts(request.tone, request.count || 7);
  }
}
serve(async (req)=>{
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: corsHeaders
    });
  }
  try {
    const { habit, reason, tone, streak, consecutiveMisses, escalationState, count = 7 } = await req.json();
    // Validate required fields
    if (!habit || !reason || !tone || typeof streak !== 'number' || typeof consecutiveMisses !== 'number' || typeof escalationState !== 'number') {
      return new Response(JSON.stringify({
        error: 'Missing required fields'
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    const roasts = await generateRoasts({
      habit,
      reason,
      tone,
      streak,
      consecutiveMisses,
      escalationState,
      count
    });
    return new Response(JSON.stringify({
      roasts
    }), {
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  } catch (error) {
    console.error('Function error:', error);
    return new Response(JSON.stringify({
      error: 'Internal server error'
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  }
});
