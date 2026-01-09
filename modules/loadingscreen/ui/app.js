/**
 * vava_loadingscreen - Application JavaScript
 * Gestion des animations, progression et messages dynamiques
 * Version: 1.0.0
 */

// ═══════════════════════════════════════════════════════════════
// CONFIGURATION PAR DÉFAUT (sera écrasée par config.lua)
// ═══════════════════════════════════════════════════════════════

const DEFAULT_CONFIG = {
    ServerName: "vAvA Roleplay",
    ServerSlogan: "L'immersion au service du RP",
    ServerVersion: "1.0.0",
    DefaultLocale: "fr",
    
    Background: {
        Image: "assets/background.png",
        Blur: 0,
        Opacity: 1.0,
        Filter: "none",
        Animation: "zoom",
        AnimationSpeed: 30
    },
    
    Logo: {
        Enabled: true,
        Image: "assets/logo.png",
        Width: 200,
        Height: 200,
        Animation: true
    },
    
    ProgressBar: {
        Style: "line",
        Color: "#e74c3c",
        BackgroundColor: "rgba(255,255,255,0.2)",
        Height: 8,
        Width: 400,
        Animated: true,
        ShowPercentage: true
    },
    
    Colors: {
        Primary: "#e74c3c",
        Secondary: "#c0392b",
        Text: "#ffffff",
        TextShadow: "rgba(0,0,0,0.5)",
        Accent: "#f39c12"
    },
    
    Messages: {
        Enabled: true,
        DisplayMode: "random",
        DisplayTime: 5000,
        FadeTime: 500
    },
    
    Music: {
        Enabled: false,
        File: "assets/music.mp3",
        Volume: 0.3,
        Loop: true,
        AutoPlay: true,
        ShowControls: true
    },
    
    Effects: {
        Particles: {
            Enabled: false,
            Type: "snow",
            Density: 50,
            Speed: 1.0
        },
        Vignette: {
            Enabled: true,
            Opacity: 0.4
        },
        Scanlines: {
            Enabled: false,
            Opacity: 0.05
        }
    },
    
    DynamicInfo: {
        ShowPlayerCount: true,
        ShowServerVersion: true,
        ShowLoadingModules: true
    },
    
    Performance: {
        LowQualityMode: false,
        DisableAnimations: false,
        MaxFPS: 60
    }
};

// ═══════════════════════════════════════════════════════════════
// MESSAGES PAR DÉFAUT (multilingue)
// ═══════════════════════════════════════════════════════════════

const MESSAGES = {
    fr: [
        "💡 Conseil : Restez en personnage pour une meilleure immersion !",
        "📜 Rappel : Lisez les règles du serveur avant de jouer.",
        "🎭 Le RP, c'est avant tout du respect mutuel.",
        "🚗 N'oubliez pas de verrouiller votre véhicule !",
        "💬 Utilisez le chat IC pour les conversations en jeu.",
        "🏥 En cas d'urgence, appelez les services d'urgence.",
        "👮 Respectez les forces de l'ordre... ou assumez les conséquences !",
        "💼 Trouvez un job pour gagner de l'argent légalement.",
        "🏠 Achetez une propriété pour stocker vos affaires.",
        "🤝 Créez des liens avec les autres joueurs !",
        "⚠️ Le FreeKill et le FailRP sont interdits.",
        "🎮 Amusez-vous et créez des histoires mémorables !"
    ],
    en: [
        "💡 Tip: Stay in character for better immersion!",
        "📜 Reminder: Read the server rules before playing.",
        "🎭 RP is about mutual respect above all.",
        "🚗 Don't forget to lock your vehicle!",
        "💬 Use IC chat for in-game conversations.",
        "🏥 In case of emergency, call emergency services.",
        "👮 Respect law enforcement... or face the consequences!",
        "💼 Find a job to earn money legally.",
        "🏠 Buy a property to store your belongings.",
        "🤝 Build relationships with other players!",
        "⚠️ FreeKill and FailRP are prohibited.",
        "🎮 Have fun and create memorable stories!"
    ],
    es: [
        "💡 Consejo: ¡Mantente en personaje para mayor inmersión!",
        "📜 Recordatorio: Lee las reglas del servidor antes de jugar.",
        "🎭 El RP se trata de respeto mutuo ante todo.",
        "🚗 ¡No olvides bloquear tu vehículo!",
        "💬 Usa el chat IC para conversaciones en el juego.",
        "🏥 En caso de emergencia, llama a los servicios de emergencia.",
        "👮 Respeta a las fuerzas del orden... ¡o asume las consecuencias!",
        "💼 Encuentra un trabajo para ganar dinero legalmente.",
        "🏠 Compra una propiedad para guardar tus pertenencias.",
        "🤝 ¡Crea vínculos con otros jugadores!",
        "⚠️ El FreeKill y el FailRP están prohibidos.",
        "🎮 ¡Diviértete y crea historias memorables!"
    ]
};

const LOADING_TEXTS = {
    fr: {
        loading: "Chargement...",
        connecting: "Connexion au serveur...",
        downloading: "Téléchargement des ressources...",
        starting: "Démarrage...",
        almost: "Presque terminé...",
        ready: "Prêt !"
    },
    en: {
        loading: "Loading...",
        connecting: "Connecting to server...",
        downloading: "Downloading resources...",
        starting: "Starting...",
        almost: "Almost done...",
        ready: "Ready!"
    },
    es: {
        loading: "Cargando...",
        connecting: "Conectando al servidor...",
        downloading: "Descargando recursos...",
        starting: "Iniciando...",
        almost: "Casi listo...",
        ready: "¡Listo!"
    }
};

// ═══════════════════════════════════════════════════════════════
// VARIABLES GLOBALES
// ═══════════════════════════════════════════════════════════════

let config = DEFAULT_CONFIG;
let currentLocale = "fr";
let currentProgress = 0;
let messageIndex = 0;
let messageInterval = null;
let progressInterval = null;
let isMuted = false;

// ═══════════════════════════════════════════════════════════════
// ÉLÉMENTS DOM
// ═══════════════════════════════════════════════════════════════

const elements = {
    loadingScreen: null,
    backgroundImage: null,
    backgroundOverlay: null,
    vignette: null,
    scanlines: null,
    particles: null,
    logo: null,
    logoContainer: null,
    serverName: null,
    serverSlogan: null,
    progressFill: null,
    progressGlow: null,
    progressText: null,
    progressPercentage: null,
    progressContainer: null,
    progressBarWrapper: null,
    dynamicMessage: null,
    messagesContainer: null,
    playersCount: null,
    serverVersion: null,
    loadingModule: null,
    playersInfo: null,
    versionInfo: null,
    modulesInfo: null,
    muteBtn: null,
    volumeIcon: null,
    backgroundMusic: null,
    audioControls: null
};

// ═══════════════════════════════════════════════════════════════
// INITIALISATION
// ═══════════════════════════════════════════════════════════════

document.addEventListener('DOMContentLoaded', () => {
    initElements();
    applyConfig();
    initAudio();
    initParticles();
    startMessageRotation();
    startProgressSimulation();
    setupEventListeners();
    
    console.log('[vava_loadingscreen] Initialized successfully');
});

function initElements() {
    elements.loadingScreen = document.getElementById('loading-screen');
    elements.backgroundImage = document.getElementById('background-image');
    elements.backgroundOverlay = document.getElementById('background-overlay');
    elements.vignette = document.getElementById('vignette');
    elements.scanlines = document.getElementById('scanlines');
    elements.particles = document.getElementById('particles');
    elements.logo = document.getElementById('logo');
    elements.logoContainer = document.getElementById('logo-container');
    elements.serverName = document.getElementById('server-name');
    elements.serverSlogan = document.getElementById('server-slogan');
    elements.progressFill = document.getElementById('progress-fill');
    elements.progressGlow = document.getElementById('progress-glow');
    elements.progressText = document.getElementById('progress-text');
    elements.progressPercentage = document.getElementById('progress-percentage');
    elements.progressContainer = document.getElementById('progress-container');
    elements.progressBarWrapper = document.getElementById('progress-bar-wrapper');
    elements.dynamicMessage = document.getElementById('dynamic-message');
    elements.messagesContainer = document.getElementById('messages-container');
    elements.playersCount = document.getElementById('players-count');
    elements.serverVersion = document.getElementById('server-version');
    elements.loadingModule = document.getElementById('loading-module');
    elements.playersInfo = document.getElementById('players-info');
    elements.versionInfo = document.getElementById('version-info');
    elements.modulesInfo = document.getElementById('modules-info');
    elements.muteBtn = document.getElementById('mute-btn');
    elements.volumeIcon = document.getElementById('volume-icon');
    elements.backgroundMusic = document.getElementById('background-music');
    elements.audioControls = document.getElementById('audio-controls');
}

// ═══════════════════════════════════════════════════════════════
// CONFIGURATION
// ═══════════════════════════════════════════════════════════════

function applyConfig() {
    currentLocale = config.DefaultLocale || 'fr';
    
    // Appliquer les couleurs CSS
    applyColors();
    
    // Appliquer les informations serveur
    if (elements.serverName) {
        elements.serverName.textContent = config.ServerName;
    }
    if (elements.serverSlogan) {
        elements.serverSlogan.textContent = config.ServerSlogan;
    }
    if (elements.serverVersion) {
        elements.serverVersion.textContent = `v${config.ServerVersion}`;
    }
    
    // Appliquer le fond
    applyBackground();
    
    // Appliquer le logo
    applyLogo();
    
    // Appliquer la barre de progression
    applyProgressBarStyle();
    
    // Appliquer les effets
    applyEffects();
    
    // Appliquer les infos dynamiques
    applyDynamicInfo();
    
    // Mode performance
    applyPerformanceMode();
}

function applyColors() {
    const root = document.documentElement;
    root.style.setProperty('--primary-color', config.Colors.Primary);
    root.style.setProperty('--secondary-color', config.Colors.Secondary);
    root.style.setProperty('--text-color', config.Colors.Text);
    root.style.setProperty('--text-shadow', config.Colors.TextShadow);
    root.style.setProperty('--accent-color', config.Colors.Accent);
    root.style.setProperty('--progress-bg', config.ProgressBar.BackgroundColor);
}

function applyBackground() {
    if (elements.backgroundImage) {
        // Image
        elements.backgroundImage.style.backgroundImage = `url('${config.Background.Image}')`;
        
        // Blur
        elements.backgroundImage.style.filter = `blur(${config.Background.Blur}px)`;
        
        // Opacité
        elements.backgroundImage.style.opacity = config.Background.Opacity;
        
        // Filtre
        if (config.Background.Filter !== 'none') {
            elements.backgroundImage.classList.add(`filter-${config.Background.Filter}`);
        }
        
        // Animation
        if (config.Background.Animation === 'parallax') {
            elements.backgroundImage.classList.remove('bg-zoom');
            elements.backgroundImage.classList.add('bg-parallax');
        } else if (config.Background.Animation === 'none') {
            elements.backgroundImage.classList.add('bg-none');
        }
        
        // Vitesse d'animation
        elements.backgroundImage.style.animationDuration = `${config.Background.AnimationSpeed}s`;
    }
}

function applyLogo() {
    if (!config.Logo.Enabled && elements.logoContainer) {
        elements.logoContainer.style.display = 'none';
        return;
    }
    
    if (elements.logo) {
        elements.logo.src = config.Logo.Image;
        elements.logo.style.width = `${config.Logo.Width}px`;
        elements.logo.style.height = `${config.Logo.Height}px`;
        
        if (!config.Logo.Animation) {
            elements.logo.classList.add('logo-no-animation');
        }
    }
}

function applyProgressBarStyle() {
    const style = config.ProgressBar.Style;
    
    if (style === 'circle') {
        createCircleProgress();
    } else if (style === 'block') {
        createBlockProgress();
    } else {
        // Style ligne par défaut
        if (elements.progressFill) {
            elements.progressFill.style.background = `linear-gradient(90deg, ${config.Colors.Primary} 0%, ${config.Colors.Accent} 100%)`;
        }
    }
    
    if (!config.ProgressBar.ShowPercentage && elements.progressPercentage) {
        elements.progressPercentage.style.display = 'none';
    }
}

function createCircleProgress() {
    if (!elements.progressBarWrapper) return;
    
    elements.progressBarWrapper.innerHTML = `
        <div class="progress-circle">
            <svg width="120" height="120" viewBox="0 0 120 120">
                <circle class="progress-circle-bg" cx="60" cy="60" r="54" />
                <circle class="progress-circle-fill" cx="60" cy="60" r="54" id="circle-fill" />
            </svg>
            <span class="progress-circle-text" id="circle-percentage">0%</span>
        </div>
    `;
    
    elements.progressFill = document.getElementById('circle-fill');
    elements.progressPercentage = document.getElementById('circle-percentage');
}

function createBlockProgress() {
    if (!elements.progressBarWrapper) return;
    
    const blockCount = 20;
    let blocksHTML = '<div class="progress-block">';
    for (let i = 0; i < blockCount; i++) {
        blocksHTML += `<div class="progress-block-item" data-index="${i}"></div>`;
    }
    blocksHTML += '</div>';
    
    elements.progressBarWrapper.innerHTML = blocksHTML;
}

function applyEffects() {
    // Vignette
    if (elements.vignette) {
        if (config.Effects.Vignette.Enabled) {
            elements.vignette.style.opacity = config.Effects.Vignette.Opacity;
        } else {
            elements.vignette.style.display = 'none';
        }
    }
    
    // Scanlines
    if (elements.scanlines) {
        if (config.Effects.Scanlines.Enabled) {
            elements.scanlines.style.opacity = config.Effects.Scanlines.Opacity;
        } else {
            elements.scanlines.style.display = 'none';
        }
    }
}

function applyDynamicInfo() {
    if (!config.DynamicInfo.ShowPlayerCount && elements.playersInfo) {
        elements.playersInfo.style.display = 'none';
    }
    if (!config.DynamicInfo.ShowServerVersion && elements.versionInfo) {
        elements.versionInfo.style.display = 'none';
    }
    if (!config.DynamicInfo.ShowLoadingModules && elements.modulesInfo) {
        elements.modulesInfo.style.display = 'none';
    }
}

function applyPerformanceMode() {
    if (config.Performance.LowQualityMode) {
        document.body.classList.add('low-quality');
    }
    if (config.Performance.DisableAnimations) {
        document.body.classList.add('no-animations');
    }
}

// ═══════════════════════════════════════════════════════════════
// AUDIO
// ═══════════════════════════════════════════════════════════════

function initAudio() {
    if (!config.Music.Enabled) {
        if (elements.audioControls) {
            elements.audioControls.style.display = 'none';
        }
        return;
    }
    
    if (!config.Music.ShowControls && elements.audioControls) {
        elements.audioControls.style.display = 'none';
    }
    
    if (elements.backgroundMusic) {
        elements.backgroundMusic.src = config.Music.File;
        elements.backgroundMusic.volume = config.Music.Volume;
        elements.backgroundMusic.loop = config.Music.Loop;
        
        if (config.Music.AutoPlay) {
            elements.backgroundMusic.play().catch(e => {
                console.log('[vava_loadingscreen] Autoplay blocked by browser');
            });
        }
    }
}

function toggleMute() {
    isMuted = !isMuted;
    
    if (elements.backgroundMusic) {
        elements.backgroundMusic.muted = isMuted;
    }
    
    if (elements.volumeIcon) {
        elements.volumeIcon.className = isMuted ? 'fas fa-volume-mute' : 'fas fa-volume-up';
    }
    
    if (elements.muteBtn) {
        elements.muteBtn.classList.toggle('muted', isMuted);
    }
}

// ═══════════════════════════════════════════════════════════════
// PARTICLES
// ═══════════════════════════════════════════════════════════════

function initParticles() {
    if (!config.Effects.Particles.Enabled || !elements.particles) return;
    
    const type = config.Effects.Particles.Type;
    const density = config.Effects.Particles.Density;
    const speed = config.Effects.Particles.Speed;
    
    for (let i = 0; i < density; i++) {
        createParticle(type, speed);
    }
}

function createParticle(type, speed) {
    const particle = document.createElement('div');
    particle.className = 'particle';
    
    // Position aléatoire
    particle.style.left = `${Math.random() * 100}%`;
    particle.style.top = `${Math.random() * -100}%`;
    
    // Taille selon le type
    let size;
    switch (type) {
        case 'snow':
            size = Math.random() * 5 + 2;
            particle.style.borderRadius = '50%';
            particle.style.background = 'rgba(255, 255, 255, 0.8)';
            break;
        case 'rain':
            size = 2;
            particle.style.width = '2px';
            particle.style.height = `${Math.random() * 20 + 10}px`;
            particle.style.background = 'rgba(174, 194, 224, 0.6)';
            particle.style.borderRadius = '0';
            break;
        case 'dust':
            size = Math.random() * 3 + 1;
            particle.style.background = 'rgba(255, 220, 180, 0.6)';
            break;
        case 'stars':
            size = Math.random() * 3 + 1;
            particle.style.background = '#fff';
            particle.style.boxShadow = '0 0 6px #fff';
            break;
        default:
            size = 3;
    }
    
    if (type !== 'rain') {
        particle.style.width = `${size}px`;
        particle.style.height = `${size}px`;
    }
    
    // Durée d'animation
    const duration = (Math.random() * 5 + 5) / speed;
    particle.style.animationDuration = `${duration}s`;
    particle.style.animationDelay = `${Math.random() * duration}s`;
    
    elements.particles.appendChild(particle);
}

// ═══════════════════════════════════════════════════════════════
// MESSAGES DYNAMIQUES
// ═══════════════════════════════════════════════════════════════

function startMessageRotation() {
    if (!config.Messages.Enabled || !elements.dynamicMessage) return;
    
    const messages = MESSAGES[currentLocale] || MESSAGES.fr;
    
    // Afficher le premier message
    showMessage(messages);
    
    // Rotation des messages
    messageInterval = setInterval(() => {
        showMessage(messages);
    }, config.Messages.DisplayTime);
}

function showMessage(messages) {
    if (!elements.dynamicMessage) return;
    
    // Fade out
    elements.dynamicMessage.classList.add('message-fade-out');
    
    setTimeout(() => {
        // Changer le message
        if (config.Messages.DisplayMode === 'random') {
            messageIndex = Math.floor(Math.random() * messages.length);
        } else {
            messageIndex = (messageIndex + 1) % messages.length;
        }
        
        elements.dynamicMessage.textContent = messages[messageIndex];
        
        // Fade in
        elements.dynamicMessage.classList.remove('message-fade-out');
    }, config.Messages.FadeTime);
}

// ═══════════════════════════════════════════════════════════════
// PROGRESSION
// ═══════════════════════════════════════════════════════════════

function startProgressSimulation() {
    // Simulation de progression pour le test
    progressInterval = setInterval(() => {
        if (currentProgress < 100) {
            const increment = Math.random() * 2 + 0.5;
            updateProgress(Math.min(currentProgress + increment, 100));
        } else {
            clearInterval(progressInterval);
        }
    }, 100);
}

function updateProgress(progress) {
    currentProgress = progress;
    const percentage = Math.floor(progress);
    
    const style = config.ProgressBar.Style;
    const texts = LOADING_TEXTS[currentLocale] || LOADING_TEXTS.fr;
    
    if (style === 'circle') {
        // Circle progress
        const circleFill = document.getElementById('circle-fill');
        const circlePercentage = document.getElementById('circle-percentage');
        
        if (circleFill) {
            const circumference = 2 * Math.PI * 54;
            const offset = circumference - (progress / 100) * circumference;
            circleFill.style.strokeDashoffset = offset;
        }
        if (circlePercentage) {
            circlePercentage.textContent = `${percentage}%`;
        }
    } else if (style === 'block') {
        // Block progress
        const blocks = document.querySelectorAll('.progress-block-item');
        const activeBlocks = Math.floor((progress / 100) * blocks.length);
        
        blocks.forEach((block, index) => {
            if (index < activeBlocks) {
                block.classList.add('active');
            } else {
                block.classList.remove('active');
            }
        });
    } else {
        // Line progress (default)
        if (elements.progressFill) {
            elements.progressFill.style.width = `${progress}%`;
        }
        if (elements.progressGlow) {
            elements.progressGlow.style.width = `${progress}%`;
        }
    }
    
    // Percentage text
    if (elements.progressPercentage) {
        elements.progressPercentage.textContent = `${percentage}%`;
    }
    
    // Loading text
    if (elements.progressText) {
        if (percentage < 20) {
            elements.progressText.textContent = texts.connecting;
        } else if (percentage < 60) {
            elements.progressText.textContent = texts.downloading;
        } else if (percentage < 90) {
            elements.progressText.textContent = texts.starting;
        } else if (percentage < 100) {
            elements.progressText.textContent = texts.almost;
        } else {
            elements.progressText.textContent = texts.ready;
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// EVENT LISTENERS
// ═══════════════════════════════════════════════════════════════

function setupEventListeners() {
    // Bouton mute
    if (elements.muteBtn) {
        elements.muteBtn.addEventListener('click', toggleMute);
    }
    
    // Écouter les messages du jeu
    window.addEventListener('message', handleGameMessage);
}

function handleGameMessage(event) {
    const data = event.data;
    
    switch (data.type) {
        case 'updateConfig':
            config = { ...DEFAULT_CONFIG, ...data.config };
            applyConfig();
            break;
            
        case 'updateProgress':
            updateProgress(data.progress);
            break;
            
        case 'updatePlayerCount':
            if (elements.playersCount) {
                const text = currentLocale === 'fr' ? 'joueurs connectés' :
                             currentLocale === 'es' ? 'jugadores conectados' : 'players online';
                elements.playersCount.textContent = `${data.count} ${text}`;
            }
            break;
            
        case 'updateLoadingModule':
            if (elements.loadingModule) {
                elements.loadingModule.textContent = data.module;
            }
            break;
            
        case 'setLocale':
            currentLocale = data.locale;
            // Redémarrer les messages avec la nouvelle langue
            if (messageInterval) {
                clearInterval(messageInterval);
            }
            startMessageRotation();
            break;
            
        case 'hide':
            hideLoadingScreen();
            break;
    }
}

function hideLoadingScreen() {
    if (elements.loadingScreen) {
        elements.loadingScreen.style.transition = 'opacity 1s ease';
        elements.loadingScreen.style.opacity = '0';
        
        setTimeout(() => {
            elements.loadingScreen.style.display = 'none';
            
            // Arrêter la musique
            if (elements.backgroundMusic) {
                elements.backgroundMusic.pause();
            }
            
            // Nettoyer les intervals
            if (messageInterval) clearInterval(messageInterval);
            if (progressInterval) clearInterval(progressInterval);
        }, 1000);
    }
}

// ═══════════════════════════════════════════════════════════════
// EXPORTS (pour FiveM)
// ═══════════════════════════════════════════════════════════════

// Ces fonctions peuvent être appelées depuis le client Lua
window.LoadingScreen = {
    updateProgress: updateProgress,
    updatePlayerCount: (count) => {
        if (elements.playersCount) {
            const text = currentLocale === 'fr' ? 'joueurs connectés' :
                         currentLocale === 'es' ? 'jugadores conectados' : 'players online';
            elements.playersCount.textContent = `${count} ${text}`;
        }
    },
    updateLoadingModule: (module) => {
        if (elements.loadingModule) {
            elements.loadingModule.textContent = module;
        }
    },
    setLocale: (locale) => {
        currentLocale = locale;
        if (messageInterval) clearInterval(messageInterval);
        startMessageRotation();
    },
    hide: hideLoadingScreen,
    setConfig: (newConfig) => {
        config = { ...DEFAULT_CONFIG, ...newConfig };
        applyConfig();
    }
};

console.log('[vava_loadingscreen] Script loaded');
