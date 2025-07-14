import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/habit_model.dart';

class SupabaseService {
  static const String _supabaseUrl = 'https://eeikiaxppvebrvrzckxm.supabase.co';
  static const String _supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVlaWtpYXhwcHZlYnJ2cnpja3htIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTEwMDY2NjUsImV4cCI6MjA2NjU4MjY2NX0.-E2hnH2DJ1G0sKajf3QGojPSRVLGoVVL3HkJauzpNlg';
  static SupabaseClient? _client;

  static SupabaseClient get client {
    _client ??= SupabaseClient(_supabaseUrl, _supabaseAnonKey);
    return _client!;
  }

  static Future<void> initialize() async {
    if (_client == null) {
      await Supabase.initialize(
        url: _supabaseUrl,
        anonKey: _supabaseAnonKey,
      );
      _client = Supabase.instance.client;
    }
  }

  Future<List<RoastTriple>> generateRoasts({
    required String habit,
    required String reason,
    required String tone,
    required int streak,
    required int consecutiveMisses,
    required int escalationState,
    int count = 7,
  }) async {

    try {
      final requestBody = {
        'habit': habit,
        'reason': reason,
        'tone': tone,
        'streak': streak,
        'consecutiveMisses': consecutiveMisses,
        'escalationState': escalationState,
        'count': count,
      };


      final response = await client.functions.invoke(
        'generate-roasts',
        body: requestBody,
      );


      if (response.data != null && response.data['roasts'] != null) {
        final roastsList = response.data['roasts'] as List<dynamic>;
        final result = roastsList
            .map((roast) => RoastTriple.fromJson(roast))
            .toList();
        return result;
      } else {
        throw Exception('Invalid response format');
      }
    } catch (e) {
      
      // Return dummy roasts on any error
      return _generateDummyRoasts(tone, count);
    }
  }

  List<RoastTriple> _generateDummyRoasts(String tone, int count) {
    final baseRoasts = {
      'motivational': [
        RoastTriple(
          screen: 'You\'ve got this! Time to make today count.',
          done: 'Amazing work! You\'re building something incredible.',
          missed: 'Tomorrow is a fresh start. Don\'t give up on yourself.',
        ),
        RoastTriple(
          screen: 'Your future self is counting on today\'s choices.',
          done: 'That\'s the spirit! Keep pushing forward.',
          missed: 'Setbacks are setups for comebacks. Keep going.',
        ),
      ],
      'mild': [
        RoastTriple(
          screen: 'Well, well... are we doing this today or what?',
          done: 'Look who decided to show up! Not bad.',
          missed: 'Seriously? We had ONE job today.',
        ),
        RoastTriple(
          screen: 'Time to put your money where your mouth is.',
          done: 'Finally! Was starting to worry about you.',
          missed: 'Another day, another creative excuse.',
        ),
      ],
      'medium': [
        RoastTriple(
          screen: 'Time to stop being a disappointment to yourself.',
          done: 'Wow, you actually did it. Color me shocked.',
          missed: 'Pathetic. Your excuses are getting weaker.',
        ),
        RoastTriple(
          screen: 'Let\'s see if you can actually follow through today.',
          done: 'Incredible! You managed basic human consistency.',
          missed: 'Another failed promise to yourself. Shocking.',
        ),
      ],
      'brutal': [
        RoastTriple(
          screen: 'Time to prove you\'re not completely useless.',
          done: 'Holy crap, you actually did something right for once.',
          missed: 'Absolutely pathetic. You\'re your own worst enemy.',
        ),
        RoastTriple(
          screen: 'Let\'s see how spectacularly you fail today.',
          done: 'Miracles do happen. You didn\'t screw up today.',
          missed: 'Congratulations, you\'ve mastered the art of failure.',
        ),
      ],
    };

    final roastList = baseRoasts[tone] ?? baseRoasts['mild']!;
    final result = <RoastTriple>[];

    for (int i = 0; i < count; i++) {
      result.add(roastList[i % roastList.length]);
    }

    return result;
  }
}