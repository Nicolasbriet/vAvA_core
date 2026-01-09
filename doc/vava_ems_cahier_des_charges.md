# 📋 Cahier des Charges - Système EMS vAvA Core

> **Version:** 1.0.0  
> **Date:** 9 janvier 2026  
> **Auteur:** vAvA Team  
> **Framework:** ESX / QBCore Compatible

---

## 🎯 1. Objectif global

Créer un système EMS réaliste, immersif, modulaire, couvrant toute la chaîne médicale RP :

**urgence → diagnostic → soins → hospitalisation → suivi → décès RP**

Le système doit offrir une expérience médicale complète et authentique, permettant aux joueurs EMS de vivre des interventions variées et complexes tout en maintenant un équilibre entre réalisme et jouabilité.

---

## 🧠 2. Système médical central

### États du joueur
- **Normal** - Aucun problème médical
- **Douleur légère / moyenne / sévère** - Affecte les actions du joueur
- **Saignement** (lent / actif / critique)
- **Inconscient** - Joueur au sol, incapable d'agir
- **Coma** - État critique prolongé
- **Arrêt cardiaque** - Nécessite réanimation immédiate
- **Mort RP** - Décès du personnage

### Signes vitaux
- **Pouls** (BPM: 40-180)
- **Tension** (systolique/diastolique)
- **Saturation O₂** (%)
- **Température** (°C)
- **Niveau de douleur** (0-10)
- **Volume sanguin** (% - critique sous 60%)

### Monitoring
- Interface HUD pour EMS
- Scanner médical portable
- Écrans vitaux en temps réel
- Alertes automatiques (critique, arrêt cardiaque)

---

## 🩸 3. Blessures & traumatologie

### Types de blessures
- **Contusions** - Bleus, impacts légers
- **Plaies ouvertes** - Coupures, lacérations
- **Fractures** 
  - Simples (fermées)
  - Ouvertes (exposition osseuse)
- **Blessures par balle**
  - Entrée
  - Sortie (si traversante)
- **Brûlures** (1er, 2e, 3e degré)
- **Traumatismes crâniens** (léger à sévère)
- **Lésions internes** (organes)
- **Hémorragies** 
  - Externes
  - Internes

### Localisation anatomique
- **Tête** - Critique, affect vision et conscience
- **Torse** - Affecte respiration et cœur
- **Abdomen** - Risque hémorragie interne
- **Bras gauche / droit** - Limite utilisation
- **Jambe gauche / droite** - Affecte mobilité

### Effets dynamiques sur le gameplay
- **Boiterie** - Vitesse réduite, animation claudication
- **Vision floue** - Shader post-traumatique
- **Tremblements** - Caméra instable, précision réduite
- **Chutes aléatoires** - Si blessures jambes sévères
- **Perte de contrôle véhicule** - Si blessures graves
- **Diminution force / précision** - Malus combat et interactions

---

## 🚑 4. Interventions EMS

### Processus d'intervention

1. **Appel d'urgence**
   - 911 via téléphone
   - Radio EMS
   - Bouton panique
   - **Géolocalisation automatique** (voir section dédiée)

2. **Dispatch**
   - Répartition des unités
   - Prioritisation selon gravité
   - Coordination multi-unités

3. **Sécurisation de zone**
   - Collaboration LSPD/Sheriff
   - Périmètre de sécurité
   - Gestion spectateurs

4. **Diagnostic interactif**
   - Évaluation initiale
   - Identification blessures
   - Triage si multi-victimes

5. **Stabilisation sur place**
   - Premiers soins
   - Contrôle hémorragies
   - Immobilisation
   - Monitoring vitaux

6. **Transport EMS**
   - Ambulance
   - Hélicoptère médical (cas critiques)
   - Soins en route

7. **Hospitalisation / sortie**
   - Transfert urgences
   - Soins légers sur place
   - Libération avec ordonnance

### 🗺️ Géolocalisation & Alertes automatiques

**Système d'alerte intelligente :**

- **Détection automatique** 
  - Joueur inconscient sans appel
  - Arrêt cardiaque détecté
  - Hémorragie critique
  - Absence de mouvement prolongée

- **Notification EMS**
  - Alerte visuelle/sonore dans le dispatch
  - Position GPS approximative (rayon 50-100m)
  - Gravité estimée (code couleur)
  - Timer depuis détection
  - Nombre de victimes potentielles

- **Types d'alertes**
  - 🔴 **Code Rouge** - Arrêt cardiaque, mort imminente
  - 🟠 **Code Orange** - Inconscient, hémorragie sévère
  - 🟡 **Code Jaune** - Blessé conscient, non urgent
  - 🔵 **Code Bleu** - Demande assistance médicale

- **Interface dispatch**
  - Liste des interventions actives
  - Carte avec marqueurs
  - Prise en charge (claim) par unité
  - Statut en temps réel
  - Historique appels

- **Anti-abus**
  - Cooldown alertes automatiques
  - Vérification état réel
  - Logs complets
  - Sanction abus répétés

### Diagnostic médical

**Outils de diagnostic :**
- **Palpation** - Détection fractures, zones douloureuses
- **Auscultation** - Sons respiratoires, cardiaques
- **Scanner portable** - Radiographie basique
- **Radio hospitalière** - Imagerie avancée
- **Analyse sanguine** - Groupe, infections, toxines
- **ECG** - Rythme cardiaque, anomalies

**Mini-jeux interactifs :**
- Skill checks pour examens
- Précision influence diagnostic
- Erreurs possibles si grade bas
- Bonus précision avec équipement avancé

---

## 🧰 5. Matériel médical

### Équipement basique
**Accessible : Stagiaire, Ambulancier**
- **Gants** - Obligatoires pour soins
- **Bandages** - Contrôle saignements légers
- **Attelles** - Immobilisation fractures
- **Antiseptiques** - Prévention infections
- **Oxygène portable** - Assistance respiratoire
- **Pansements compressifs** - Hémorragies modérées

### Équipement avancé
**Accessible : Paramedic, Médecin**
- **Défibrillateur** - Arrêts cardiaques
- **Perfusions (IV)**
  - NaCl (réhydratation)
  - Glucose (hypoglycémie)
  - Ringer lactate (volume sanguin)
- **Morphine / antidouleur** - Gestion douleur
- **Adrénaline** - Choc, arrêt cardiaque
- **Kit suture** - Plaies profondes
- **Kit thoracique** - Pneumothorax
- **Planche dorsale** - Traumatismes colonne

### Équipement critique
**Accessible : Médecin, Chirurgien**
- **Intubation** - Ventilation artificielle
- **Ventilation mécanique** - Assistance respiratoire prolongée
- **Chirurgie d'urgence** - Bloc opératoire mobile
- **Réanimation avancée** - Protocoles complexes
- **Échographie portable** - Hémorragies internes
- **Transfusion sanguine** - Kit mobile

### Véhicules & équipements spéciaux
- **Ambulance standard** - Équipement basique/avancé
- **Ambulance de réanimation** - Équipement critique
- **Hélicoptère médical** - Transport rapide + soins avancés
- **Unité mobile de chirurgie** - Intervention lourde sur site

---

## 🩸 6. Sang, transfusions & don du sang

### Groupes sanguins & compatibilité

**Groupes disponibles :**
- **A+** / **A-**
- **B+** / **B-**
- **AB+** / **AB-** (receveur universel si +)
- **O+** / **O-** (donneur universel)

**Tableau de compatibilité :**
```
Receveur  | Peut recevoir de
----------|----------------------------------
O-        | O-
O+        | O-, O+
A-        | O-, A-
A+        | O-, O+, A-, A+
B-        | O-, B-
B+        | O-, O+, B-, B+
AB-       | O-, A-, B-, AB-
AB+       | TOUS
```

### Don du sang

**Processus de don :**
- **Don volontaire RP** 
  - Citoyen se présente à l'hôpital
  - Questionnaire de santé
  - Prélèvement (animation + temps)
  - Compensation symbolique (collation RP)
  
- **Don PNJ** 
  - Génération automatique stocks
  - Réalisme (quantités réalistes)
  
- **Réserve hôpital**
  - Stock par groupe sanguin
  - Capacité limitée
  - Gestion des stocks
  - Alertes pénurie

**Limitations & effets :**
- **Cooldown don** - 56 jours RP (ou configuration)
- **Effets post-don**
  - Fatigue temporaire
  - Malaise si effort intense
  - Bonus moral/récompense RP
- **Conditions pour donner**
  - Bonne santé
  - Pas de maladies actives
  - Poids minimal

### Transfusion sanguine

**Protocole transfusion :**
1. Vérification groupe sanguin patient
2. Test compatibilité (si disponible)
3. Préparation poche sanguine
4. Transfusion (durée réaliste)
5. Monitoring réaction

**Risques & complications :**
- **Incompatibilité** 
  - Choc transfusionnel
  - Aggravation état
  - Risque décès si non traitée
- **Stock insuffisant**
  - Nécessite don d'urgence
  - Appel à la communauté
  - PNJ en dernier recours
- **Contamination** (rare, scénario RP)

**Effets transfusion :**
- Restauration volume sanguin
- Amélioration signes vitaux
- Stabilisation état
- Prévention mort par hémorragie

---

## 🏥 7. Hôpital & soins prolongés

### Zones hospitalières

**Rez-de-chaussée :**
- **Accueil / Réception** - Enregistrement, rendez-vous
- **Urgences** - Accueil patients critiques
- **Salle de tri** - Évaluation et priorisation
- **Salles de consultation** - Examens, soins légers
- **Radiologie** - Scanner, IRM, rayons X
- **Laboratoire d'analyses** - Prélèvements, résultats
- **Pharmacie** - Délivrance médicaments

**Étage(s) supérieur(s) :**
- **Bloc opératoire** - Chirurgies programmées/urgentes
- **Salle de réveil** - Post-opératoire immédiat
- **Réanimation / USI** - Soins intensifs
- **Chambres d'hospitalisation** - Séjours prolongés
- **Salle de repos EMS** - Pause, vestiaires

**Sous-sol :**
- **Banque du sang** - Stockage, gestion dons
- **Morgue** - Conservation corps, autopsies
- **Archives médicales** - Dossiers patients
- **Locaux techniques** - Maintenance, stockage

### Soins hospitaliers avancés

**Chirurgie :**
- Mini-jeu chirurgical (skill checks)
- Durée selon intervention
- Complications possibles
- Spécialités :
  - Chirurgie générale
  - Neurochirurgie
  - Chirurgie thoracique
  - Orthopédie

**Réanimation :**
- Ventilation assistée
- Monitoring intensif
- Médication intraveineuse
- Soins infirmiers constants

**Hospitalisation RP :**
- Chambre attribuée
- Visites autorisées/restreintes
- Évolution état (amélioration progressive)
- Rééducation post-trauma
- Sortie sur avis médical

---

## ☠️ 8. Coma & Mort RP

### État de coma

**Déclenchement :**
- Traumatisme crânien sévère
- Hémorragie cérébrale
- Arrêt cardiaque prolongé
- Choc septique
- Surdosage médicamenteux

**Caractéristiques :**
- **Timer évolutif** 
  - Phase critique (0-30 min)
  - Phase stabilisée (30 min - 6h)
  - Phase prolongée (6h+)
- **Possibilité de stabilisation**
  - Soins intensifs
  - Chirurgie si nécessaire
  - Monitoring permanent
- **Réveil progressif**
  - Signes d'amélioration
  - Reprise conscience
  - Période de confusion
- **Séquelles possibles**
  - Amnésie partielle
  - Troubles moteurs temporaires
  - Besoin rééducation
  - Suivi médical obligatoire

### Mort RP (Roleplay Death)

**Conditions de déclenchement :**
- Blessures incompatibles avec survie
- Absence soins prolongée (timer expiré)
- Arrêt cardiaque non réanimé
- Hémorragie massive non contrôlée
- Décision consensuelle RP
- Validation staff obligatoire

**Processus mort RP :**
1. **Constatation décès**
   - Médecin EMS autorisé
   - Vérification absence signes vitaux
   - Heure du décès enregistrée

2. **Certificat de décès**
   - Document officiel
   - Cause du décès
   - Circonstances
   - Signature médecin

3. **Implications RP**
   - Enquête LSPD si mort suspecte
   - Autopsie possible
   - Contact famille/amis
   - Cérémonie funéraire

4. **Conséquences personnage**
   - **Effacement partiel** (configuration serveur)
     - Perte argent liquide
     - Perte compétences spécifiques
     - Conservation propriétés/véhicules
   - **Effacement total**
     - Nouveau personnage obligatoire
     - Perte complète progression
     - Nouvelle histoire RP

**Prévention abus :**
- Logs détaillés
- Validation staff requise
- Cooldown mort RP (limite farming)
- Sanction exploits

---

## 👥 9. Personnel EMS & hiérarchie

### Grades & responsabilités

**🟦 Stagiaire EMS**
- Formation initiale
- Observation interventions
- Soins basiques supervisés
- Conduite ambulance (avec superviseur)
- Accès matériel basique uniquement

**🟩 Ambulancier**
- Interventions solo autorisées
- Soins premiers secours
- Transport patients
- Conduite ambulance certifiée
- Rapport incidents

**🟨 Paramedic**
- Interventions complexes
- Diagnostic avancé
- Utilisation matériel avancé
- Mentorat stagiaires
- Prise décisions terrain

**🟧 Médecin**
- Toutes interventions
- Chirurgie d'urgence
- Prescription médicaments
- Gestion cas critiques
- Supervision équipes

**🟥 Chirurgien**
- Chirurgie complexe
- Bloc opératoire
- Spécialisations médicales
- Consultation expertise
- Formation personnel

**🟪 Chef EMS**
- Coordination équipes
- Gestion plannings
- Discipline interne
- Recrutement/formations
- Interface direction

**⬛ Directeur médical**
- Direction service EMS
- Budgets & ressources
- Protocoles médicaux
- Relations LEO/Gouvernement
- Décisions stratégiques

### Système de progression
- Heures de service requises
- Interventions réussies
- Formations complétées
- Évaluations par supérieurs
- Examens pratiques/théoriques

---

## 📚 10. Formations & certifications

### Programme de formation

**🎓 Niveau 1 : Premiers secours**
- Évaluation victime
- RCP (Réanimation Cardio-Pulmonaire)
- Contrôle hémorragies
- Position latérale sécurité
- Alertes et communications
- **Durée :** 2h RP minimum
- **Certification :** Requis pour Ambulancier

**🎓 Niveau 2 : Traumatologie**
- Types de blessures
- Immobilisation avancée
- Diagnostic traumatismes
- Gestion multi-victimes
- Triage d'urgence
- **Durée :** 3h RP minimum
- **Certification :** Requis pour Paramedic

**🎓 Niveau 3 : Conduite d'urgence**
- Code de la route urgence
- Conduite défensive
- Gyrophares & sirène
- Itinéraires optimisés
- Sécurité transport patient
- **Durée :** 2h RP + pratique
- **Certification :** Requis toutes conduites

**🎓 Niveau 4 : Chirurgie RP**
- Anatomie avancée
- Techniques chirurgicales
- Gestion bloc opératoire
- Anesthésie
- Post-opératoire
- **Durée :** 5h RP minimum
- **Certification :** Requis pour Chirurgien

**🎓 Niveau 5 : Réanimation avancée**
- Protocoles ACLS
- Intubation
- Médicaments d'urgence
- Défibrillation
- Gestion arrêt cardiaque
- **Durée :** 4h RP minimum
- **Certification :** Requis pour Médecin

**🎓 Formation spécialisée : Gestion crise de masse**
- Plan blanc (afflux massif)
- Coordination multi-services
- Triage avancé
- Communication crise
- Gestion ressources limitées
- **Durée :** 3h RP minimum
- **Certification :** Optionnelle (Chef EMS)

### Système de validation

**Méthodes d'évaluation :**
- **Quiz théoriques** - Connaissances médicales
- **Simulations pratiques** - Scénarios encadrés
- **Évaluation terrain** - Interventions supervisées
- **Examens finaux** - Validation complète

**Diplômes & badges :**
- Certificats numériques
- Badges dans dossier personnel
- Affichage grades/certifications
- Renouvellement périodique (optionnel)

**Accès conditionnel :**
- Matériel débloqué par certification
- Zones hospitalières restreintes
- Actions médicales par grade
- Véhicules spécialisés

---

## 🚓 11. Interactions RP avec autres services

### LSPD / Sheriff / DOJ

**Sécurisation de scène :**
- LEO sécurise périmètre
- EMS attend feu vert
- Coordination radio
- Protection personnel médical

**Rapports blessures :**
- Fiche médicale pour enquête
- Nature blessures (compatibles déclarations)
- Balistique (entrée/sortie balles)
- Estimation heure blessure
- État conscience victime

**Certificat de décès :**
- Document officiel pour LEO
- Cause probable
- Circonstances suspectes
- Autorisation transport corps
- Transmission au DOJ

**Prélèvements médico-légaux :**
- Échantillons sang/tissus
- Conservation chaîne preuve
- Analyse toxicologique
- Collaboration autopsie
- Témoignage expert médical

**Situations spéciales :**
- Suspects blessés (menottés)
- Garde LEO à l'hôpital
- Soins en détention
- Évasion pendant soins
- Secret médical vs enquête

### Interaction avec civils

**Consentement soins :**
- Demande autorisation (si conscient)
- Explication procédures
- Respect refus (sauf danger vital)
- Témoin si possible
- Documentation dans dossier

**Refus de soins RP :**
- Liberté du joueur
- Décharge responsabilité signée
- Explication risques
- Possibilité changement avis
- Exception : danger pour tiers

**Don du sang volontaire :**
- Campagnes sensibilisation
- Donateurs réguliers
- Reconnaissance communautaire
- Compensation symbolique
- Fidélisation donateurs

**Suivi médical RP :**
- Rendez-vous de contrôle
- Prescriptions à suivre
- Rééducation
- Certificats médicaux (emploi, justice)
- Dossier médical partagé (avec consentement)

**Visites hospitalières :**
- Horaires de visite
- Limitation nombre visiteurs
- Respect état patient
- Salle d'attente
- Accompagnement situations graves

---

## 🦠 12. Maladies & états pathologiques RP

### Infections & pathologies

**Infection (plaies) :**
- Déclenchement si soins tardifs/absents
- Symptômes : fièvre, douleur, rougeur
- Traitement : antibiotiques + soins locaux
- Risque : septicémie

**Septicémie (infection généralisée) :**
- État critique
- Choc septique possible
- Hospitalisation urgente
- Antibiotiques IV
- Risque décès élevé

**Maladies chroniques (RP) :**
- Diabète (gestion glycémie)
- Asthme (crises respiratoires)
- Épilepsie (crises convulsives)
- Cardiaque (risque arrêt)
- Nécessite traitement régulier

### États aigus

**Overdose (drogues/médicaments) :**
- Détection signes vitaux anormaux
- Identification substance (si possible)
- Antidote spécifique (Narcan pour opiacés)
- Lavage gastrique
- Hospitalisation + suivi psychiatrique

**Déshydratation :**
- Causes : effort, chaleur, maladie
- Symptômes : malaise, confusion, faiblesse
- Traitement : réhydratation IV
- Prévention : eau, repos

**Hypothermie :**
- Exposition au froid
- Tremblements, confusion, léthargie
- Réchauffement progressif
- Hospitalisation si sévère
- Risque arrêt cardiaque

**Hyperthermie (coup de chaleur) :**
- Exposition chaleur intense
- Fièvre, confusion, convulsions
- Refroidissement urgent
- Réhydratation
- Dommages organes possibles

**Malaise vagal :**
- Perte connaissance brève
- Chute tension artérielle
- Soins légers
- Position allongée
- Surveillance récidive

### Système de contagion (optionnel)

**Épidémies RP :**
- Événements scriptés
- Propagation entre joueurs
- Quarantaine
- Vaccins/traitements
- Gestion crise sanitaire

---

## 💊 13. Médicaments & effets secondaires

### Catégories de médicaments

**Antidouleurs (Analgésiques) :**
- **Paracétamol** - Douleur légère
- **Ibuprofène** - Douleur moyenne + anti-inflammatoire
- **Morphine** - Douleur sévère
- **Fentanyl** - Douleur extrême (hospitalier)

**Antibiotiques :**
- **Amoxicilline** - Infections courantes
- **Ciprofloxacine** - Infections graves
- **Traitement : 3-7 jours**
- **Nécessite prescription**

**Sédatifs / Anxiolytiques :**
- **Diazépam** - Anxiété, convulsions
- **Midazolam** - Sédation procédure
- **Propofol** - Anesthésie générale

**Anesthésie :**
- **Locale** - Lidocaïne (sutures)
- **Régionale** - Rachianesthésie
- **Générale** - Propofol + agents volatils

**Antidotes spécifiques :**
- **Naloxone (Narcan)** - Overdose opiacés
- **Atropine** - Intoxication organophosphorés
- **Charbon actif** - Absorption toxines

**Médicaments d'urgence :**
- **Adrénaline** - Choc anaphylactique, arrêt cardiaque
- **Atropine** - Bradycardie sévère
- **Amiodarone** - Arythmies ventriculaires
- **Glucose** - Hypoglycémie

### Risques & complications

**Surdosage :**
- Symptômes selon médicament
- Risque vital
- Nécessite antidote ou épuration
- Hospitalisation urgente
- Séquelles possibles

**Allergies médicamenteuses :**
- Réaction cutanée
- Choc anaphylactique (grave)
- Documentation dossier médical
- Bracelet allergie
- Contre-indication absolue

**Dépendance RP :**
- Antidouleurs opiacés
- Anxiolytiques
- Symptômes sevrage si arrêt brutal
- Nécessite sevrage progressif
- Suivi addictologie

**Interactions médicamenteuses :**
- Potentialisation effets
- Inefficacité traitement
- Toxicité
- Vérification dossier médical
- Rôle pharmacien

**Effets secondaires courants :**
- Nausées, vomissements
- Somnolence
- Vertiges
- Confusion
- Impact gameplay temporaire

---

## 💰 14. Facturation & économie médicale

### Grille tarifaire

**Interventions pré-hospitalières :**
- **Appel EMS** - Gratuit
- **Intervention sur site** - $250-500
- **Soins légers** - $100-300
- **Soins avancés** - $500-1,000
- **Transport ambulance** - $500-750/km
- **Transport héliporté** - $5,000-10,000

**Soins hospitaliers :**
- **Consultation urgences** - $300-600
- **Radiographie** - $400
- **Scanner/IRM** - $1,500
- **Analyses sanguines** - $200-500
- **Sutures** - $300-800
- **Plâtre/attelle** - $500-1,200

**Interventions chirurgicales :**
- **Chirurgie mineure** - $2,000-5,000
- **Chirurgie majeure** - $10,000-25,000
- **Neurochirurgie** - $30,000-50,000
- **Bloc opératoire** - $3,000/heure
- **Anesthésie** - $1,500-3,000

**Hospitalisation :**
- **Chambre standard** - $500/jour
- **Réanimation** - $2,000/jour
- **Médicaments** - Variable ($50-500)
- **Soins infirmiers** - Inclus
- **Transfusion sanguine** - $1,500-3,000

**Services additionnels :**
- **Certificat médical** - $100
- **Dossier médical (copie)** - $50
- **Rapport d'expertise** - $500-1,000
- **Don du sang** - Gratuit (compensation symbolique)

### Options de paiement

**Assurance santé RP :**
- Souscription mensuelle ($500-2,000)
- Couverture partielle/totale (selon formule)
- Franchise applicable
- Plafond annuel
- Exclusions (activités criminelles)

**Prise en charge État :**
- Citoyens revenus faibles
- Soins essentiels couverts
- Délais de traitement
- Dossier à constituer

**Facturation LSPD :**
- Blessures en service
- Suspects blessés (si condamnés)
- Certificats médico-légaux
- Convention inter-services

**Paiement direct :**
- Cash accepté
- Carte bancaire
- Paiement différé (dette RP)
- Recouvrement possible
- Intérêts retard

**Impayés & conséquences :**
- Relances
- Pénalités
- Saisie sur salaire RP
- Limitation soins non-urgents
- Dossier contentieux

---

## 📝 15. Dossiers médicaux & confidentialité

### Contenu du dossier patient

**Informations personnelles :**
- Identité complète
- Date de naissance
- Adresse
- Numéro téléphone
- Contact d'urgence
- Assurance santé

**Données médicales :**
- **Groupe sanguin** (fixe)
- **Allergies** (médicaments, latex, etc.)
- **Antécédents** 
  - Maladies chroniques
  - Chirurgies passées
  - Hospitalisations
  - Traumas majeurs
- **Traitements en cours**
- **Vaccinations** (si applicable RP)

**Historique interventions :**
- Date & heure
- Lieu intervention
- Nature blessures
- Soins prodigués
- Médecin responsable
- Suivi prescrit
- Évolution état

**Documents annexes :**
- Résultats analyses
- Images médicales (radios, scanner)
- Rapports chirurgicaux
- Certificats médicaux délivrés
- Consentements signés

### Accès & sécurité

**Accès autorisés :**
- **Patient** - Consultation complète (sur demande)
- **Médecins EMS** - Accès complet (nécessité médicale)
- **Personnel soignant** - Accès partiel (selon intervention)
- **Staff serveur** - Logs et vérifications
- **LEO** - Uniquement avec mandat ou consentement

**Sécurité des données :**
- Système de permissions par grade
- Logs des accès (qui/quand/quoi)
- Chiffrement des données sensibles
- Sauvegarde régulière
- Sanctions divulgation illicite

**Secret médical :**
- Obligation légale RP
- Exceptions :
  - Danger imminent pour tiers
  - Mandat judiciaire
  - Maladies à déclaration obligatoire
  - Abus/maltraitance
- Sanctions violation grave

**Interface dossier médical :**
- Système de recherche patient
- Édition/ajout informations
- Consultation historique
- Export PDF (pour partage autorisé)
- Archivage automatique

---

## 🛡️ 16. Sécurité & anti-abus

### Mécanismes de protection

**Cooldowns soins :**
- Délai entre deux soins identiques (30s-2min)
- Empêche spam heal
- Exceptions situations critiques
- Notification cooldown actif

**Anti-heal combat :**
- Détection combat actif
- Blocage soins pendant combat
- Délai sécurité après combat (30-60s)
- Exceptions EMS externes (non impliqués)
- Message explicite au joueur

**Zones de sécurité :**
- Hôpital = zone protégée
- Pas d'agressions
- Sanctions automatiques
- Exceptions scénarios staff validés

**Protection EMS en service :**
- Identification visuelle (uniforme, badge)
- Invulnérabilité optionnelle (configuration)
- Sanctions lourdes agression EMS
- Logs automatiques incidents

### Système de logs

**Logs complets EMS :**
- Toutes actions médicales
- Timestamp + coordonnées
- ID joueur soigneur + soigné
- Type de soins
- Items utilisés
- Résultat (succès/échec)

**Logs accessibles :**
- **En jeu** (Chefs EMS) - Dernières 24h
- **Panel admin** - Historique complet
- **Exports** - CSV/JSON pour analyses
- **Recherche** - Par joueur, date, action

**Alertes automatiques :**
- Détection comportements suspects
- Heal spam
- Usage items sans RP
- Téléportations hôpital suspectes
- Notification staff en temps réel

### Permissions & grades

**Système de permissions :**
- Basé sur grades EMS
- Granularité fine (par action)
- Vérification côté serveur (sécurité)
- Pas de bypass possible
- Logs tentatives non autorisées

**Blocage actions hors RP :**
- Impossibilité soigner en voiture (sauf ambulance)
- Pas de soins en course/nage
- Distance maximale pour soigner
- Vérification animation joueur
- Message pédagogique si bloqué

### Protection économique

**Limite items portés :**
- Stock maximum par joueur
- Empêche farm items
- Restock ambulance/hôpital obligatoire
- Traçabilité distribution

**Facturation obligatoire :**
- Logs toutes prestations
- Détection soins gratuits répétés
- Audit possible
- Sanctions abus

**Anti-exploit mort RP :**
- Cooldown entre morts RP
- Validation staff obligatoire
- Logs circonstances décès
- Détection patterns suspects

---

## ⚙️ 17. Configuration & compatibilité

### Framework & dépendances

**Compatibilité frameworks :**
- **ESX Legacy** - Support natif
- **QBCore** - Support natif
- Système de détection automatique
- Adaptateurs pour autres frameworks

**Dépendances requises :**
- **Base framework** (ESX/QBCore)
- **oxmysql** / **mysql-async** - Base de données
- **vAvA_core** - Système central

**Dépendances optionnelles :**
- **pma-voice** / **tokovoip** - Proximité vocale
- **progressBars** - Animations soins
- **target system** - Interactions (ox_target, qb-target)
- **inventory** - Gestion items médicaux
- **dispatch** - Intégration alertes (cd_dispatch, ps-dispatch)

### Paramétrage difficulté

**Mode Soft (Casual RP) :**
- Timer inconscience : Long (15-30 min)
- Saignement : Lent
- Douleur : Impact réduit
- Mort RP : Rare / consentie
- Coûts : Modérés
- Soins civils : Basiques autorisés

**Mode Normal (Balanced RP) :**
- Timer inconscience : Moyen (8-15 min)
- Saignement : Progressif
- Douleur : Impact moyen
- Mort RP : Possible selon blessures
- Coûts : Réalistes
- Soins civils : Limités

**Mode Hardcore (Realistic RP) :**
- Timer inconscience : Court (3-8 min)
- Saignement : Rapide
- Douleur : Impact fort (handicaps)
- Mort RP : Fréquente si non soigné
- Coûts : Élevés
- Soins civils : Inefficaces

**Mode Custom :**
- Tous paramètres ajustables
- Profils multiples sauvegardables
- Hot-reload configuration
- Tests in-game

### Configuration modulaire

**Fichier config principal :**
```lua
Config = {
    -- Général
    Framework = 'auto', -- 'esx', 'qbcore', 'auto'
    Locale = 'fr',
    
    -- Gameplay
    DifficultyMode = 'normal', -- 'soft', 'normal', 'hardcore', 'custom'
    UnconsciousTimer = 10, -- minutes
    BleedingSpeed = 1.0, -- multiplicateur
    PainEffects = true,
    PermaDeath = false,
    
    -- Économie
    EnableBilling = true,
    InsuranceSystem = true,
    PriceMultiplier = 1.0,
    
    -- Features
    BloodSystem = true,
    DiseaseSystem = false,
    AdvancedDiagnostic = true,
    AutoAlerts = true,
    
    -- Anti-abus
    CombatHealBlock = true,
    HealCooldown = 30, -- secondes
    EMSInvulnerable = false
}
```

### API inter-scripts

**Exports disponibles :**
```lua
-- Obtenir l'état de santé d'un joueur
exports['vava_ems']:GetPlayerHealth(playerId)

-- Appliquer des dégâts
exports['vava_ems']:ApplyDamage(playerId, bodyPart, damage, type)

-- Soigner un joueur
exports['vava_ems']:HealPlayer(playerId, healType)

-- Vérifier si un joueur est EMS
exports['vava_ems']:IsPlayerEMS(playerId)

-- Déclencher alerte automatique
exports['vava_ems']:TriggerAutoAlert(coords, severity)

-- Obtenir le groupe sanguin
exports['vava_ems']:GetBloodType(playerId)
```

**Events disponibles :**
```lua
-- Côté serveur
TriggerEvent('vava_ems:playerUnconscious', playerId)
TriggerEvent('vava_ems:playerRevived', playerId, medicId)
TriggerEvent('vava_ems:playerDeath', playerId)
TriggerEvent('vava_ems:callReceived', callData)

-- Côté client
TriggerEvent('vava_ems:updateHealth', healthData)
TriggerEvent('vava_ems:showNotification', message, type)
```

---

## 🧪 18. Scénarios avancés & événements

### Accidents de masse

**Déclenchement :**
- Crash aérien
- Accident autoroutier multiple
- Explosion
- Fusillade
- Catastrophe naturelle (événement RP)

**Gestion spécifique :**
- **Alerte masse** - Notification tous EMS en service
- **Triage multiple** - Code couleur victime
  - 🔴 Urgence absolue
  - 🟠 Urgence relative
  - 🟡 Soins différés possibles
  - 🟢 Soins légers
  - ⚫ Décédé
- **Coordination équipes** - Dispatch centralisé
- **Poste médical avancé** - Zone de stabilisation sur site
- **Flux victimes** - Priorisation transports
- **Communication** - Radio dédiée, updates réguliers

### Catastrophes RP

**Types de catastrophes :**
- **Incendie majeur** (building, forêt)
- **Inondation**
- **Séisme** (dégâts structurels)
- **Attentat terroriste**
- **Épidémie** (contagion)
- **Accident chimique** (zone contaminée)

**Protocole plan blanc :**
1. Activation par Directeur médical
2. Rappel personnel hors service
3. Réquisition lits supplémentaires
4. Activation zones d'attente
5. Priorisation soins vitaux
6. Collaboration LEO/Pompiers
7. Communication médias RP

**Équipement spécialisé :**
- Combinaisons HAZMAT
- Tentes médicales
- Générateurs portables
- Stocks d'urgence augmentés
- Poste de commandement mobile

### Pénuries & crises

**Manque de sang :**
- Alertes système automatique
- Appel communautaire donateurs
- Priorisation interventions critiques
- Transfusions réduites
- Conséquences RP (décès évitables)

**Manque de personnel :**
- Heures supplémentaires obligatoires
- Recrutement accéléré
- Interventions retardées
- Fatigue personnel (RP)
- Baisse qualité soins potentielle

**EMS débordés :**
- File d'attente appels
- Délais d'intervention allongés
- Priorisation stricte (triage téléphonique)
- Civils invités premiers secours basiques
- Tensions RP avec patients/familles

**Épidémies :**
- Propagation entre joueurs
- Zones de quarantaine
- EMS en première ligne (risque)
- Équipements protection
- Recherche traitement RP
- Vaccination massive

---

## 📦 19. Livrables & documentation

### Scripts & fichiers

**Structure livrée :**
```
vAvA_ems/
├── fxmanifest.lua
├── config.lua
├── README.md
├── INSTALLATION.md
├── CHANGELOG.md
├── LICENSE
├── client/
│   ├── main.lua
│   ├── health.lua
│   ├── injuries.lua
│   ├── hud.lua
│   ├── interactions.lua
│   └── ... 
├── server/
│   ├── main.lua
│   ├── medical.lua
│   ├── billing.lua
│   ├── database.lua
│   ├── dispatch.lua
│   └── ...
├── shared/
│   ├── config.lua
│   ├── injuries.lua
│   ├── medications.lua
│   └── ...
├── database/
│   ├── install.sql
│   ├── migrations.lua
│   └── ...
├── html/ (Interface UI)
│   ├── index.html
│   ├── css/
│   ├── js/
│   └── images/
├── locales/
│   ├── fr.lua
│   ├── en.lua
│   └── es.lua
└── docs/
    ├── GUIDE_EMS.md
    ├── GUIDE_STAFF.md
    ├── API_REFERENCE.md
    └── ...
```

### Documentation complète

**📘 Guide EMS (joueurs) :**
- Introduction au job EMS
- Hiérarchie et grades
- Procédures d'intervention
- Utilisation matériel médical
- Protocoles médicaux simplifiés
- Interactions RP
- FAQ

**📙 Guide Staff :**
- Installation et configuration
- Gestion des permissions
- Administration système
- Résolution problèmes courants
- Validation morts RP
- Gestion événements
- Création scénarios médicaux

**📗 API Reference :**
- Exports disponibles
- Events déclenchables
- Structure données
- Exemples d'intégration
- Hooks et callbacks

**📕 Logs Admin :**
- Types de logs disponibles
- Accès et consultation
- Recherche et filtres
- Export données
- Analyse comportements
- Détection abus

---

## 🧭 20. Évolutions possibles & roadmap

### Phase 1 - Stabilisation (v1.0)
✅ Système médical central  
✅ Blessures & traumatologie  
✅ Interventions EMS basiques  
✅ Matériel médical  
✅ Hôpital & soins  
✅ Hiérarchie & grades  

### Phase 2 - Enrichissement (v1.5)
🔄 Système sanguin complet  
🔄 Maladies & pathologies  
🔄 Médicaments avancés  
🔄 Formations certifiantes  
🔄 Facturation & économie  
🔄 Dossiers médicaux persistants  

### Phase 3 - Avancé (v2.0)
🔮 Handicap permanent  
🔮 Prothèses et implants RP  
🔮 Spécialisations médicales  
🔮 Recherche médicale RP  
🔮 Épidémies dynamiques  
🔮 Mutations génétiques RP (si serveur futuriste)  

### Phase 4 - Intelligence (v2.5)
🔮 EMS PNJ IA (backup)  
🔮 Diagnostic assisté IA  
🔮 Prédiction complications  
🔮 Optimisation dispatch automatique  
🔮 Tutoriels interactifs  

### Fonctionnalités communautaires
- 📱 Application mobile de don du sang
- 🏆 Système de statistiques EMS (interventions, sauvetages)
- 🎖️ Badges de mérite et récompenses
- 📺 Télémédecine (consultations à distance)
- 🚁 Système de SAMU/SMUR avancé
- 🧬 Système de génétique (maladies héréditaires)
- 💉 Addiction médicaments (système étendu)
- 🦴 Rééducation physique (mini-jeux)
- 🧠 Santé mentale (psychologie RP)
- 🩺 Consultations préventives

---

## ✅ Conclusion

Ce cahier des charges définit un système EMS complet, réaliste et modulaire pour vAvA Core. L'objectif est de créer une expérience médicale immersive qui enrichit le roleplay tout en maintenant un équilibre entre réalisme et plaisir de jeu.

### Principes fondamentaux
- **Réalisme** - Procédures médicales authentiques
- **Immersion** - Expérience RP profonde
- **Équilibre** - Gameplay vs réalisme
- **Modularité** - Configuration adaptable
- **Performance** - Optimisation serveur
- **Anti-abus** - Sécurité et fair-play

### Engagement qualité
- Code propre et documenté
- Tests approfondis
- Support et maintenance
- Écoute communauté
- Mises à jour régulières

---

**Document créé le :** 9 janvier 2026  
**Dernière mise à jour :** 9 janvier 2026  
**Version :** 1.0.0  
**Statut :** ✅ Validé  

---

*© 2026 vAvA Team - Tous droits réservés*
