#!/usr/bin/env python3
"""One-shot conversion of assets/seed/grammar_rules.json (French-only fr→ko)
into assets/seed/grammar/ko/rules.json: locale-map content fields (fr + en),
worked examples as {target, translations}, prerequisites by registry list id,
dead `templates` dropped. Rule ids are preserved (grammar_progress keys on
them). English translations LLM-generated (Claude, 2026-08-08) pending review.
"""
import json, os

SRC = '/home/thomas/vocabulary_app/assets/seed/grammar_rules.json'
OUT = '/home/thomas/vocabulary_app/assets/seed/grammar/ko/rules.json'

LIST_IDS = {
    'Salutations & politesse': 'starter-greetings',
    'Les nombres & le temps': 'starter-numbers-time',
    'La nourriture': 'starter-food',
    'La vie quotidienne': 'starter-daily-life',
    'Se déplacer': 'starter-getting-around',
    'Les particules essentielles': 'starter-ko-particles',
}

EN = {
 'particule-theme-eun-neun': {
  'title': 'The topic particle 은/는',
  'description': 'Mark the topic of the sentence with 은 after a final consonant and 는 after a vowel.',
  'explanation': "In Korean, the particle 은/는 attaches to the word the sentence is about: its topic. It often corresponds to \"as for…\" or to the general subject in English. The choice between the two forms is purely phonetic: if the word ends in a final consonant (batchim), add 은; if it ends in a vowel, add 는. For example: 학생 + 은 → 학생은, but 친구 + 는 → 친구는. This particle is also used to mark a contrast between two elements.",
  'examples': ["I am a student.", 'The teacher is at school right now.', 'Today, I am busy.'],
 },
 'particules-sujet-objet-i-ga-eul-reul': {
  'title': 'The subject particles 이/가 and object particles 을/를',
  'description': 'Mark the grammatical subject with 이/가 and the direct object with 을/를 according to the word ending.',
  'explanation': 'The particle 이/가 marks the grammatical subject (who does the action, or what is being described); the particle 을/를 marks the direct object (what undergoes the action). The choice depends only on the final sound of the word: after a final consonant (batchim), use 이 for the subject and 을 for the object; after a vowel, use 가 and 를. Examples: 물이 (subject), 친구가 (subject), 밥을 (object), 우유를 (object). Unlike 은/는, which presents a topic, 이/가 highlights new information or an answer to "who? / what?".',
  'examples': ['My friend is coming.', 'The water tastes bad.', 'I eat rice.', 'I drink milk.'],
 },
 'present-poli-ayo-eoyo': {
  'title': 'The polite present in 아요/어요',
  'description': "Conjugate verbs and adjectives in the polite present according to the stem's vowel harmony.",
  'explanation': 'To conjugate in the polite present, remove 다 from the dictionary form to get the stem, then add an ending according to vowel harmony: if the last vowel of the stem is ㅏ or ㅗ, add 아요; otherwise, add 어요; 하다 verbs become 해요. Contractions apply when the stem ends in a vowel: 가 + 아요 → 가요, 오 + 아요 → 와요, 보 + 아요 → 봐요, 마시 + 어요 → 마셔요. Some verbs are irregular: 듣다 → 들어요, 돕다 → 도와요, 바쁘다 → 바빠요.',
  'examples': ['I drink coffee in the morning.', 'My friend is arriving now.', 'I live in Seoul.'],
 },
 'particules-lieu-e-eseo': {
  'title': 'The place particles 에 and 에서',
  'description': 'Distinguish 에 (destination, time) from 에서 (place where an action happens).',
  'explanation': 'The particle 에 marks the destination of movement ("to, toward") with verbs like 가다, 오다, 도착하다, and also the moment ("at, on") with time words: 학교에 가요, 아침에 일어나요. The particle 에서 marks the place where an action takes place ("at, in") with action verbs: 식당에서 밥을 먹어요, 회사에서 일해요. Neither 에 nor 에서 changes form with the word ending: they attach as-is after a consonant or a vowel. Tip: movement toward → 에; activity on the spot → 에서.',
  'examples': ['In the morning, I go to school.', 'I eat at the restaurant.', 'My friend comes from France.'],
 },
 'negation-an': {
  'title': 'Negation with 안',
  'description': 'Form the negative by placing 안 right before the conjugated verb or adjective.',
  'explanation': 'To negate an action or a state, place the adverb 안 immediately before the conjugated verb or adjective: 가요 → 안 가요, 먹어요 → 안 먹어요. Important exception: for "noun + 하다" compound verbs (공부하다, 일하다…), 안 goes between the noun and 하다: 공부해요 → 공부 안 해요, not 안 공부해요. The verb 좋아하다 is an exception to the exception: say 안 좋아해요. For 맛있다, the language prefers the opposite adjective 맛없어요 rather than 안 맛있어요. 안 is written separated from the verb by a space.',
  'examples': ["Today I'm not going to school.", "I don't drink coffee.", "Tomorrow I'm not working."],
 },
}

src = json.load(open(SRC))
rules = []
for item in src:
    r = item['rule']
    en = EN[r['id']]
    assert len(en['examples']) == len(r['worked_examples']), r['id']
    rules.append({'rule': {
        'id': r['id'],
        'title': {'fr': r['title_fr'], 'en': en['title']},
        'description': {'fr': r['description_fr'], 'en': en['description']},
        'explanation': {'fr': r['explanation_fr'], 'en': en['explanation']},
        'prerequisite_lists': [LIST_IDS[n] for n in r['prerequisite_lists']],
        'min_known_words': r['min_known_words'],
        'applies_to_categories': r['applies_to_categories'],
        'mechanics': r['mechanics'],
        'worked_examples': [
            {'target': w['ko'],
             'translations': {'fr': w['fr'], 'en': en['examples'][i]}}
            for i, w in enumerate(r['worked_examples'])
        ],
        'test_vectors': r['test_vectors'],
    }})

os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, 'w') as f:
    json.dump({'lang': 'ko', 'rules': rules}, f, ensure_ascii=False, indent=2)
    f.write('\n')
print('rules:', len(rules))
