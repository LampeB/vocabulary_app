#!/usr/bin/env python3
"""Generates assets/seed/vocab/lang/{en,it,de,es}.json from the tables below,
adds gender tags to fr.json nouns, and adds English fallbacks to ko.json notes.

Content status: LLM-generated (Claude, 2026-08-08) pending native review —
see docs/seed-content-authoring.md. Word/example rows: (word, tags, example).
Tags carry grammatical metadata for drills: m/f/n = gender (common nouns only;
proper nouns stay untagged so article drills skip them).
"""
import json, sys

OUT = '/home/thomas/vocabulary_app/assets/seed/vocab/lang'

EN = {
 'bonjour': ('hello', [], 'Hello, teacher!'),
 'au-revoir-a-celui-qui-part': ('goodbye (to someone leaving)', [], None),
 'au-revoir-a-celui-qui-reste': ('goodbye (to someone staying)', [], None),
 'merci': ('thank you', [], 'Thank you, teacher.'),
 'de-rien': ("you're welcome", [], None),
 'pardon-excusez-moi': ('excuse me / sorry', [], None),
 'donnez-moi-s-il-vous-plait': ('please give me…', [], None),
 'oui': ('yes', [], None),
 'non': ('no', [], None),
 'enchante-e': ('nice to meet you', [], None),
 'bonne-nuit': ('good night', [], None),
 'd-accord-compris': ('okay / got it', [], None),
 'comment-allez-vous': ('how are you?', [], None),
 'je-moi-forme-humble': ('I / me (humble)', [], None),
 'nom': ('name', [], None),
 'ami': ('friend', [], None),
 'professeur': ('teacher', [], 'Hello, teacher!'),
 'personne': ('person', [], None),
 'un': ('one', [], None), 'deux': ('two', [], None),
 'trois': ('three', [], None), 'quatre': ('four', [], None),
 'cinq': ('five', [], None), 'six': ('six', [], None),
 'sept': ('seven', [], None), 'huit': ('eight', [], None),
 'neuf': ('nine', [], None), 'dix': ('ten', [], None),
 'aujourd-hui': ('today', [], None), 'demain': ('tomorrow', [], None),
 'hier': ('yesterday', [], None), 'maintenant': ('now', [], None),
 'temps-heure-duree': ('time', [], None), 'matin': ('morning', [], None),
 'soir': ('evening', [], None), 'journee': ('day', [], None),
 'riz-repas': ('rice / meal', [], 'I eat rice.'),
 'eau': ('water', [], 'Water, please.'),
 'kimchi': ('kimchi', [], 'Kimchi is delicious!'),
 'viande': ('meat', [], None), 'fruit': ('fruit', [], None),
 'pomme': ('apple', [], None), 'the': ('tea', [], None),
 'cafe-boisson': ('coffee', [], 'A coffee, please.'),
 'lait': ('milk', [], None), 'pain': ('bread', [], None),
 'poisson-aliment': ('fish (food)', [], None),
 'legume': ('vegetable', [], None),
 'manger': ('to eat', [], 'I eat bread in the morning.'),
 'boire': ('to drink', [], 'I am drinking coffee now.'),
 'delicieux': ('delicious', [], "It's delicious!"),
 'mauvais-au-gout': ('bad-tasting', [], None),
 'avoir-faim': ('to be hungry', [], "I'm hungry!"),
 'restaurant': ('restaurant', [], None),
 'maison': ('house / home', [], 'I am going home now.'),
 'ecole': ('school', [], None),
 'entreprise-bureau': ('company / office', [], None),
 'dormir': ('to sleep', [], 'I am sleeping now.'),
 'se-lever': ('to get up', [], None),
 'aller': ('to go', [], 'I go to school.'),
 'venir': ('to come', [], 'My friend comes tomorrow.'),
 'voir-regarder': ('to see / watch', [], None),
 'faire': ('to do', [], None),
 'etudier': ('to study', [], 'I study in the morning.'),
 'travailler': ('to work', [], None),
 'lire': ('to read', [], 'I read a book.'),
 'acheter': ('to buy', [], 'I buy bread.'),
 'ecouter': ('to listen', [], None),
 'aimer-apprecier': ('to like', [], 'I like coffee.'),
 'vivre-habiter': ('to live', [], None),
 'livre': ('book', [], None),
 'telephone-portable': ('cell phone', [], None),
 'etudiant': ('student', [], None),
 'etre-occupe': ('to be busy', [], 'I am busy today.'),
 'metro': ('subway', [], 'I take the subway.'),
 'bus': ('bus', [], None), 'taxi': ('taxi', [], None),
 'train': ('train', [], None),
 'rue-chemin': ('street / way', [], None),
 'gare-station': ('station', [], None),
 'aeroport': ('airport', [], None),
 'coree': ('Korea', [], None), 'france': ('France', [], None),
 'seoul': ('Seoul', [], None), 'paris': ('Paris', [], None),
 'ici': ('here', [], 'I get off here.'),
 'la-bas': ('over there', [], None),
 'ou': ('where', [], None),
 'marcher': ('to walk', [], None),
 'prendre-un-transport': ('to take (transport)', [], 'I take the bus.'),
 'descendre-d-un-transport': ('to get off', [], None),
 'arriver': ('to arrive', [], None),
 'partir': ('to leave', [], None),
 'aider': ('to help', [], None),
 'ko-particule-de-theme-apres-consonne':
     ('topic particle (after consonant)', [], 'Today, I am busy.'),
 'ko-particule-de-theme-apres-voyelle':
     ('topic particle (after vowel)', [], 'Me, I drink coffee.'),
 'ko-particule-de-sujet-apres-consonne':
     ('subject particle (after consonant)', [], 'The water is not good.'),
 'ko-particule-de-sujet-apres-voyelle':
     ('subject particle (after vowel)', [], 'My friend is coming.'),
 'ko-particule-d-objet-apres-consonne':
     ('object particle (after consonant)', [], 'I eat rice.'),
 'ko-particule-d-objet-apres-voyelle':
     ('object particle (after vowel)', [], 'I drink milk.'),
 'ko-a-vers-destination-temps':
     ('to / toward (destination, time)', [], 'In the morning I go to school.'),
 'ko-a-dans-lieu-d-action':
     ('at / in (place of action)', [], 'I eat at the restaurant.'),
 'ko-aussi': ('also / too', [], "I'm going too."),
 'ko-et-avec-apres-voyelle':
     ('and / with (after vowel)', [], 'I buy milk and bread.'),
 'ko-et-avec-apres-consonne':
     ('and / with (after consonant)', [], 'I buy bread and milk.'),
 'ko-et-avec-oral':
     ('and / with (spoken)', [], 'I drink coffee with a friend.'),
 'ko-de-possession': ('of (possession)', [], "my friend's book"),
 'ko-a-partir-de-depuis':
     ('from / since', [], 'I work from morning to evening.'),
 'ko-jusqu-a': ('until / up to', [], 'I walk to the station.'),
 'ko-seulement': ('only', [], 'Only water, please.'),
 'ko-ne-pas-negation': ('not (negation)', [], "Today I'm not going to school."),
}

IT = {
 'bonjour': ('buongiorno', [], 'Buongiorno, professore!'),
 'au-revoir-a-celui-qui-part': ('arrivederci (a chi parte)', [], None),
 'au-revoir-a-celui-qui-reste': ('arrivederci (a chi resta)', [], None),
 'merci': ('grazie', [], 'Grazie, professore.'),
 'de-rien': ('prego', [], None),
 'pardon-excusez-moi': ('scusi / mi scusi', [], None),
 'donnez-moi-s-il-vous-plait': ('mi dia…, per favore', [], None),
 'oui': ('sì', [], None),
 'non': ('no', [], None),
 'enchante-e': ('piacere', [], None),
 'bonne-nuit': ('buonanotte', [], None),
 'd-accord-compris': ("d'accordo / capito", [], None),
 'comment-allez-vous': ('come sta?', [], None),
 'je-moi-forme-humble': ('io / me (umile)', [], None),
 'nom': ('nome', ['m'], None),
 'ami': ('amico', ['m'], None),
 'professeur': ('professore', ['m'], 'Buongiorno, professore!'),
 'personne': ('persona', ['f'], None),
 'un': ('uno', [], None), 'deux': ('due', [], None),
 'trois': ('tre', [], None), 'quatre': ('quattro', [], None),
 'cinq': ('cinque', [], None), 'six': ('sei', [], None),
 'sept': ('sette', [], None), 'huit': ('otto', [], None),
 'neuf': ('nove', [], None), 'dix': ('dieci', [], None),
 'aujourd-hui': ('oggi', [], None), 'demain': ('domani', [], None),
 'hier': ('ieri', [], None), 'maintenant': ('adesso', [], None),
 'temps-heure-duree': ('tempo', ['m'], None),
 'matin': ('mattina', ['f'], None), 'soir': ('sera', ['f'], None),
 'journee': ('giornata', ['f'], None),
 'riz-repas': ('riso / pasto', ['m'], 'Mangio il riso.'),
 'eau': ('acqua', ['f'], "Dell'acqua, per favore."),
 'kimchi': ('kimchi', ['m'], 'Il kimchi è buonissimo!'),
 'viande': ('carne', ['f'], None), 'fruit': ('frutta', ['f'], None),
 'pomme': ('mela', ['f'], None), 'the': ('tè', ['m'], None),
 'cafe-boisson': ('caffè', ['m'], 'Un caffè, per favore.'),
 'lait': ('latte', ['m'], None), 'pain': ('pane', ['m'], None),
 'poisson-aliment': ('pesce', ['m'], None),
 'legume': ('verdura', ['f'], None),
 'manger': ('mangiare', [], 'La mattina mangio il pane.'),
 'boire': ('bere', [], 'Adesso bevo un caffè.'),
 'delicieux': ('buonissimo', [], 'È buonissimo!'),
 'mauvais-au-gout': ('cattivo (di sapore)', [], None),
 'avoir-faim': ('avere fame', [], 'Ho fame!'),
 'restaurant': ('ristorante', ['m'], None),
 'maison': ('casa', ['f'], 'Adesso torno a casa.'),
 'ecole': ('scuola', ['f'], None),
 'entreprise-bureau': ('azienda / ufficio', ['f'], None),
 'dormir': ('dormire', [], 'Adesso dormo.'),
 'se-lever': ('alzarsi', [], None),
 'aller': ('andare', [], 'Vado a scuola.'),
 'venir': ('venire', [], 'Il mio amico viene domani.'),
 'voir-regarder': ('vedere / guardare', [], None),
 'faire': ('fare', [], None),
 'etudier': ('studiare', [], 'Studio la mattina.'),
 'travailler': ('lavorare', [], None),
 'lire': ('leggere', [], 'Leggo un libro.'),
 'acheter': ('comprare', [], 'Compro il pane.'),
 'ecouter': ('ascoltare', [], None),
 'aimer-apprecier': ('piacere (mi piace)', [], 'Mi piace il caffè.'),
 'vivre-habiter': ('vivere / abitare', [], None),
 'livre': ('libro', ['m'], None),
 'telephone-portable': ('cellulare', ['m'], None),
 'etudiant': ('studente', ['m'], None),
 'etre-occupe': ('essere impegnato', [], 'Oggi sono impegnato.'),
 'metro': ('metropolitana', ['f'], 'Prendo la metropolitana.'),
 'bus': ('autobus', ['m'], None), 'taxi': ('taxi', ['m'], None),
 'train': ('treno', ['m'], None),
 'rue-chemin': ('strada', ['f'], None),
 'gare-station': ('stazione', ['f'], None),
 'aeroport': ('aeroporto', ['m'], None),
 'coree': ('Corea', [], None), 'france': ('Francia', [], None),
 'seoul': ('Seul', [], None), 'paris': ('Parigi', [], None),
 'ici': ('qui', [], 'Scendo qui.'),
 'la-bas': ('laggiù', [], None),
 'ou': ('dove', [], None),
 'marcher': ('camminare', [], None),
 'prendre-un-transport': ('prendere (un mezzo)', [], "Prendo l'autobus."),
 'descendre-d-un-transport': ('scendere (da un mezzo)', [], None),
 'arriver': ('arrivare', [], None),
 'partir': ('partire', [], None),
 'aider': ('aiutare', [], None),
 'ko-particule-de-theme-apres-consonne':
     ('particella del tema (dopo consonante)', [], 'Oggi sono impegnato.'),
 'ko-particule-de-theme-apres-voyelle':
     ('particella del tema (dopo vocale)', [], 'Io bevo il caffè.'),
 'ko-particule-de-sujet-apres-consonne':
     ('particella del soggetto (dopo consonante)', [], "L'acqua non è buona."),
 'ko-particule-de-sujet-apres-voyelle':
     ('particella del soggetto (dopo vocale)', [], 'Il mio amico viene.'),
 'ko-particule-d-objet-apres-consonne':
     ("particella dell'oggetto (dopo consonante)", [], 'Mangio il riso.'),
 'ko-particule-d-objet-apres-voyelle':
     ("particella dell'oggetto (dopo vocale)", [], 'Bevo il latte.'),
 'ko-a-vers-destination-temps':
     ('a / verso (destinazione, tempo)', [], 'La mattina vado a scuola.'),
 'ko-a-dans-lieu-d-action':
     ("a / in (luogo dell'azione)", [], 'Mangio al ristorante.'),
 'ko-aussi': ('anche', [], "Ci vado anch'io."),
 'ko-et-avec-apres-voyelle':
     ('e / con (dopo vocale)', [], 'Compro latte e pane.'),
 'ko-et-avec-apres-consonne':
     ('e / con (dopo consonante)', [], 'Compro pane e latte.'),
 'ko-et-avec-oral':
     ('e / con (parlato)', [], 'Bevo un caffè con un amico.'),
 'ko-de-possession': ('di (possesso)', [], 'il libro del mio amico'),
 'ko-a-partir-de-depuis':
     ('da (a partire da)', [], 'Lavoro dalla mattina alla sera.'),
 'ko-jusqu-a': ('fino a', [], 'Cammino fino alla stazione.'),
 'ko-seulement': ('solo / soltanto', [], "Solo acqua, per favore."),
 'ko-ne-pas-negation': ('non (negazione)', [], 'Oggi non vado a scuola.'),
}

DE = {
 'bonjour': ('hallo / guten Tag', [], 'Guten Tag, Herr Lehrer!'),
 'au-revoir-a-celui-qui-part': ('auf Wiedersehen (zum Gehenden)', [], None),
 'au-revoir-a-celui-qui-reste': ('auf Wiedersehen (zum Bleibenden)', [], None),
 'merci': ('danke', [], 'Danke, Herr Lehrer.'),
 'de-rien': ('gern geschehen', [], None),
 'pardon-excusez-moi': ('Entschuldigung', [], None),
 'donnez-moi-s-il-vous-plait': ('geben Sie mir bitte…', [], None),
 'oui': ('ja', [], None),
 'non': ('nein', [], None),
 'enchante-e': ('freut mich', [], None),
 'bonne-nuit': ('gute Nacht', [], None),
 'd-accord-compris': ('in Ordnung / verstanden', [], None),
 'comment-allez-vous': ('wie geht es Ihnen?', [], None),
 'je-moi-forme-humble': ('ich (bescheiden)', [], None),
 'nom': ('Name', ['m'], None),
 'ami': ('Freund', ['m'], None),
 'professeur': ('Lehrer', ['m'], 'Guten Tag, Herr Lehrer!'),
 'personne': ('Person', ['f'], None),
 'un': ('eins', [], None), 'deux': ('zwei', [], None),
 'trois': ('drei', [], None), 'quatre': ('vier', [], None),
 'cinq': ('fünf', [], None), 'six': ('sechs', [], None),
 'sept': ('sieben', [], None), 'huit': ('acht', [], None),
 'neuf': ('neun', [], None), 'dix': ('zehn', [], None),
 'aujourd-hui': ('heute', [], None), 'demain': ('morgen', [], None),
 'hier': ('gestern', [], None), 'maintenant': ('jetzt', [], None),
 'temps-heure-duree': ('Zeit', ['f'], None),
 'matin': ('Morgen', ['m'], None), 'soir': ('Abend', ['m'], None),
 'journee': ('Tag', ['m'], None),
 'riz-repas': ('Reis / Mahlzeit', ['m'], 'Ich esse Reis.'),
 'eau': ('Wasser', ['n'], 'Wasser, bitte.'),
 'kimchi': ('Kimchi', ['n'], 'Kimchi ist lecker!'),
 'viande': ('Fleisch', ['n'], None), 'fruit': ('Obst', ['n'], None),
 'pomme': ('Apfel', ['m'], None), 'the': ('Tee', ['m'], None),
 'cafe-boisson': ('Kaffee', ['m'], 'Einen Kaffee, bitte.'),
 'lait': ('Milch', ['f'], None), 'pain': ('Brot', ['n'], None),
 'poisson-aliment': ('Fisch', ['m'], None),
 'legume': ('Gemüse', ['n'], None),
 'manger': ('essen', [], 'Morgens esse ich Brot.'),
 'boire': ('trinken', [], 'Ich trinke jetzt einen Kaffee.'),
 'delicieux': ('lecker', [], 'Das ist lecker!'),
 'mauvais-au-gout': ('nicht lecker', [], None),
 'avoir-faim': ('Hunger haben', [], 'Ich habe Hunger!'),
 'restaurant': ('Restaurant', ['n'], None),
 'maison': ('Haus / Zuhause', ['n'], 'Ich gehe jetzt nach Hause.'),
 'ecole': ('Schule', ['f'], None),
 'entreprise-bureau': ('Firma / Büro', ['f'], None),
 'dormir': ('schlafen', [], 'Ich schlafe jetzt.'),
 'se-lever': ('aufstehen', [], None),
 'aller': ('gehen', [], 'Ich gehe zur Schule.'),
 'venir': ('kommen', [], 'Mein Freund kommt morgen.'),
 'voir-regarder': ('sehen / schauen', [], None),
 'faire': ('machen', [], None),
 'etudier': ('lernen', [], 'Ich lerne morgens.'),
 'travailler': ('arbeiten', [], None),
 'lire': ('lesen', [], 'Ich lese ein Buch.'),
 'acheter': ('kaufen', [], 'Ich kaufe Brot.'),
 'ecouter': ('hören', [], None),
 'aimer-apprecier': ('mögen', [], 'Ich mag Kaffee.'),
 'vivre-habiter': ('leben / wohnen', [], None),
 'livre': ('Buch', ['n'], None),
 'telephone-portable': ('Handy', ['n'], None),
 'etudiant': ('Student', ['m'], None),
 'etre-occupe': ('beschäftigt sein', [], 'Ich bin heute beschäftigt.'),
 'metro': ('U-Bahn', ['f'], 'Ich nehme die U-Bahn.'),
 'bus': ('Bus', ['m'], None), 'taxi': ('Taxi', ['n'], None),
 'train': ('Zug', ['m'], None),
 'rue-chemin': ('Straße / Weg', ['f'], None),
 'gare-station': ('Bahnhof', ['m'], None),
 'aeroport': ('Flughafen', ['m'], None),
 'coree': ('Korea', [], None), 'france': ('Frankreich', [], None),
 'seoul': ('Seoul', [], None), 'paris': ('Paris', [], None),
 'ici': ('hier', [], 'Ich steige hier aus.'),
 'la-bas': ('dort drüben', [], None),
 'ou': ('wo', [], None),
 'marcher': ('zu Fuß gehen', [], None),
 'prendre-un-transport': ('nehmen (Verkehrsmittel)', [], 'Ich nehme den Bus.'),
 'descendre-d-un-transport': ('aussteigen', [], None),
 'arriver': ('ankommen', [], None),
 'partir': ('abfahren / losgehen', [], None),
 'aider': ('helfen', [], None),
 'ko-particule-de-theme-apres-consonne':
     ('Themapartikel (nach Konsonant)', [], 'Heute bin ich beschäftigt.'),
 'ko-particule-de-theme-apres-voyelle':
     ('Themapartikel (nach Vokal)', [], 'Ich trinke Kaffee.'),
 'ko-particule-de-sujet-apres-consonne':
     ('Subjektpartikel (nach Konsonant)', [], 'Das Wasser ist nicht gut.'),
 'ko-particule-de-sujet-apres-voyelle':
     ('Subjektpartikel (nach Vokal)', [], 'Mein Freund kommt.'),
 'ko-particule-d-objet-apres-consonne':
     ('Objektpartikel (nach Konsonant)', [], 'Ich esse Reis.'),
 'ko-particule-d-objet-apres-voyelle':
     ('Objektpartikel (nach Vokal)', [], 'Ich trinke Milch.'),
 'ko-a-vers-destination-temps':
     ('nach / zu (Ziel, Zeit)', [], 'Morgens gehe ich zur Schule.'),
 'ko-a-dans-lieu-d-action':
     ('in / an (Ort der Handlung)', [], 'Ich esse im Restaurant.'),
 'ko-aussi': ('auch', [], 'Ich gehe auch.'),
 'ko-et-avec-apres-voyelle':
     ('und / mit (nach Vokal)', [], 'Ich kaufe Milch und Brot.'),
 'ko-et-avec-apres-consonne':
     ('und / mit (nach Konsonant)', [], 'Ich kaufe Brot und Milch.'),
 'ko-et-avec-oral':
     ('und / mit (gesprochen)', [], 'Ich trinke Kaffee mit einem Freund.'),
 'ko-de-possession': ('von (Besitz)', [], 'das Buch meines Freundes'),
 'ko-a-partir-de-depuis':
     ('von / ab (seit)', [], 'Ich arbeite von morgens bis abends.'),
 'ko-jusqu-a': ('bis', [], 'Ich gehe zu Fuß bis zum Bahnhof.'),
 'ko-seulement': ('nur', [], 'Nur Wasser, bitte.'),
 'ko-ne-pas-negation': ('nicht (Verneinung)', [], 'Heute gehe ich nicht zur Schule.'),
}

ES = {
 'bonjour': ('hola / buenos días', [], '¡Buenos días, profesor!'),
 'au-revoir-a-celui-qui-part': ('adiós (a quien se va)', [], None),
 'au-revoir-a-celui-qui-reste': ('adiós (a quien se queda)', [], None),
 'merci': ('gracias', [], 'Gracias, profesor.'),
 'de-rien': ('de nada', [], None),
 'pardon-excusez-moi': ('perdón / disculpe', [], None),
 'donnez-moi-s-il-vous-plait': ('deme…, por favor', [], None),
 'oui': ('sí', [], None),
 'non': ('no', [], None),
 'enchante-e': ('encantado/a', [], None),
 'bonne-nuit': ('buenas noches', [], None),
 'd-accord-compris': ('vale / entendido', [], None),
 'comment-allez-vous': ('¿cómo está?', [], None),
 'je-moi-forme-humble': ('yo / mí (humilde)', [], None),
 'nom': ('nombre', ['m'], None),
 'ami': ('amigo', ['m'], None),
 'professeur': ('profesor', ['m'], '¡Buenos días, profesor!'),
 'personne': ('persona', ['f'], None),
 'un': ('uno', [], None), 'deux': ('dos', [], None),
 'trois': ('tres', [], None), 'quatre': ('cuatro', [], None),
 'cinq': ('cinco', [], None), 'six': ('seis', [], None),
 'sept': ('siete', [], None), 'huit': ('ocho', [], None),
 'neuf': ('nueve', [], None), 'dix': ('diez', [], None),
 'aujourd-hui': ('hoy', [], None), 'demain': ('mañana', [], None),
 'hier': ('ayer', [], None), 'maintenant': ('ahora', [], None),
 'temps-heure-duree': ('tiempo', ['m'], None),
 'matin': ('mañana (parte del día)', ['f'], None),
 'soir': ('tarde / noche', ['f'], None),
 'journee': ('día', ['m'], None),
 'riz-repas': ('arroz / comida', ['m'], 'Como arroz.'),
 'eau': ('agua', ['f'], 'Agua, por favor.'),
 'kimchi': ('kimchi', ['m'], '¡El kimchi está riquísimo!'),
 'viande': ('carne', ['f'], None), 'fruit': ('fruta', ['f'], None),
 'pomme': ('manzana', ['f'], None), 'the': ('té', ['m'], None),
 'cafe-boisson': ('café', ['m'], 'Un café, por favor.'),
 'lait': ('leche', ['f'], None), 'pain': ('pan', ['m'], None),
 'poisson-aliment': ('pescado', ['m'], None),
 'legume': ('verdura', ['f'], None),
 'manger': ('comer', [], 'Por la mañana como pan.'),
 'boire': ('beber', [], 'Ahora bebo un café.'),
 'delicieux': ('riquísimo', [], '¡Está riquísimo!'),
 'mauvais-au-gout': ('malo (de sabor)', [], None),
 'avoir-faim': ('tener hambre', [], '¡Tengo hambre!'),
 'restaurant': ('restaurante', ['m'], None),
 'maison': ('casa', ['f'], 'Ahora vuelvo a casa.'),
 'ecole': ('escuela', ['f'], None),
 'entreprise-bureau': ('empresa / oficina', ['f'], None),
 'dormir': ('dormir', [], 'Ahora duermo.'),
 'se-lever': ('levantarse', [], None),
 'aller': ('ir', [], 'Voy a la escuela.'),
 'venir': ('venir', [], 'Mi amigo viene mañana.'),
 'voir-regarder': ('ver / mirar', [], None),
 'faire': ('hacer', [], None),
 'etudier': ('estudiar', [], 'Estudio por la mañana.'),
 'travailler': ('trabajar', [], None),
 'lire': ('leer', [], 'Leo un libro.'),
 'acheter': ('comprar', [], 'Compro pan.'),
 'ecouter': ('escuchar', [], None),
 'aimer-apprecier': ('gustar (me gusta)', [], 'Me gusta el café.'),
 'vivre-habiter': ('vivir', [], None),
 'livre': ('libro', ['m'], None),
 'telephone-portable': ('móvil', ['m'], None),
 'etudiant': ('estudiante', ['m'], None),
 'etre-occupe': ('estar ocupado', [], 'Hoy estoy ocupado.'),
 'metro': ('metro', ['m'], 'Tomo el metro.'),
 'bus': ('autobús', ['m'], None), 'taxi': ('taxi', ['m'], None),
 'train': ('tren', ['m'], None),
 'rue-chemin': ('calle / camino', ['f'], None),
 'gare-station': ('estación', ['f'], None),
 'aeroport': ('aeropuerto', ['m'], None),
 'coree': ('Corea', [], None), 'france': ('Francia', [], None),
 'seoul': ('Seúl', [], None), 'paris': ('París', [], None),
 'ici': ('aquí', [], 'Me bajo aquí.'),
 'la-bas': ('allí', [], None),
 'ou': ('dónde', [], None),
 'marcher': ('caminar', [], None),
 'prendre-un-transport': ('tomar (un transporte)', [], 'Tomo el autobús.'),
 'descendre-d-un-transport': ('bajarse (de un transporte)', [], None),
 'arriver': ('llegar', [], None),
 'partir': ('salir / irse', [], None),
 'aider': ('ayudar', [], None),
 'ko-particule-de-theme-apres-consonne':
     ('partícula de tema (tras consonante)', [], 'Hoy estoy ocupado.'),
 'ko-particule-de-theme-apres-voyelle':
     ('partícula de tema (tras vocal)', [], 'Yo bebo café.'),
 'ko-particule-de-sujet-apres-consonne':
     ('partícula de sujeto (tras consonante)', [], 'El agua no está buena.'),
 'ko-particule-de-sujet-apres-voyelle':
     ('partícula de sujeto (tras vocal)', [], 'Mi amigo viene.'),
 'ko-particule-d-objet-apres-consonne':
     ('partícula de objeto (tras consonante)', [], 'Como arroz.'),
 'ko-particule-d-objet-apres-voyelle':
     ('partícula de objeto (tras vocal)', [], 'Bebo leche.'),
 'ko-a-vers-destination-temps':
     ('a / hacia (destino, tiempo)', [], 'Por la mañana voy a la escuela.'),
 'ko-a-dans-lieu-d-action':
     ('en (lugar de la acción)', [], 'Como en el restaurante.'),
 'ko-aussi': ('también', [], 'Yo también voy.'),
 'ko-et-avec-apres-voyelle':
     ('y / con (tras vocal)', [], 'Compro leche y pan.'),
 'ko-et-avec-apres-consonne':
     ('y / con (tras consonante)', [], 'Compro pan y leche.'),
 'ko-et-avec-oral':
     ('y / con (hablado)', [], 'Bebo un café con un amigo.'),
 'ko-de-possession': ('de (posesión)', [], 'el libro de mi amigo'),
 'ko-a-partir-de-depuis':
     ('desde', [], 'Trabajo desde la mañana hasta la noche.'),
 'ko-jusqu-a': ('hasta', [], 'Camino hasta la estación.'),
 'ko-seulement': ('solo / solamente', [], 'Solo agua, por favor.'),
 'ko-ne-pas-negation': ('no (negación)', [], 'Hoy no voy a la escuela.'),
}

# Gender tags for the existing French layer (nouns/places with articles;
# proper nouns stay untagged so article drills skip them).
FR_TAGS = {
 'nom': 'm', 'ami': 'm', 'professeur': 'm', 'personne': 'f',
 'temps-heure-duree': 'm', 'matin': 'm', 'soir': 'm', 'journee': 'f',
 'riz-repas': 'm', 'eau': 'f', 'kimchi': 'm', 'viande': 'f', 'fruit': 'm',
 'pomme': 'f', 'the': 'm', 'cafe-boisson': 'm', 'lait': 'm', 'pain': 'm',
 'poisson-aliment': 'm', 'legume': 'm', 'restaurant': 'm', 'maison': 'f',
 'ecole': 'f', 'entreprise-bureau': 'f', 'livre': 'm',
 'telephone-portable': 'm', 'etudiant': 'm', 'metro': 'm', 'bus': 'm',
 'taxi': 'm', 'train': 'm', 'rue-chemin': 'f', 'gare-station': 'f',
 'aeroport': 'm',
}


def build(lang, table, registry_ids):
    missing = registry_ids - set(table)
    extra = set(table) - registry_ids
    if missing or extra:
        sys.exit(f'{lang}: missing={sorted(missing)} extra={sorted(extra)}')
    entries = {}
    for cid in sorted(table):
        word, tags, example = table[cid]
        entry = {'words': [{'word': word, 'is_primary': True, 'position': 0,
                            **({'tags': tags} if tags else {})}]}
        if example:
            entry['example'] = example
        entries[cid] = entry
    return {'lang': lang, 'entries': entries}


def main():
    registry = json.load(open(f'{OUT}/../registry.json'))
    ids = {c['id'] for c in registry['concepts']}

    for lang, table in [('en', EN), ('it', IT), ('de', DE), ('es', ES)]:
        data = build(lang, table, ids)
        with open(f'{OUT}/{lang}.json', 'w') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write('\n')
        print(lang, len(data['entries']), 'entries')

    # Backfill French gender tags in place.
    fr = json.load(open(f'{OUT}/fr.json'))
    for cid, gender in FR_TAGS.items():
        fr['entries'][cid]['words'][0]['tags'] = [gender]
    with open(f'{OUT}/fr.json', 'w') as f:
        json.dump(fr, f, ensure_ascii=False, indent=2)
        f.write('\n')
    print('fr tags:', len(FR_TAGS))


if __name__ == '__main__':
    main()
