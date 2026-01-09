/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                     vAvA Creator - JavaScript                                 ║
║                     Logique UI & Communication NUI                            ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

// ═══════════════════════════════════════════════════════════════════════════
// VARIABLES GLOBALES
// ═══════════════════════════════════════════════════════════════════════════

let currentStep = 0;
let currentSkin = {};
let config = {};
let isFirstTime = false;
let characters = [];
let maxCharacters = 3;
let currentShopType = null;
let shopData = {};

const STEPS = [
    { id: 'gender', title: 'SEXE', description: 'Choisissez le sexe de votre personnage' },
    { id: 'morphology', title: 'MORPHOLOGIE', description: 'Définissez l\'héritage génétique' },
    { id: 'face', title: 'VISAGE', description: 'Personnalisez les traits du visage' },
    { id: 'hair', title: 'CHEVEUX', description: 'Choisissez votre coupe et couleur' },
    { id: 'skin', title: 'PEAU', description: 'Ajoutez des détails à la peau' },
    { id: 'clothes', title: 'VÊTEMENTS', description: 'Habillez votre personnage' },
    { id: 'identity', title: 'IDENTITÉ', description: 'Donnez un nom à votre personnage' },
    { id: 'summary', title: 'RÉSUMÉ', description: 'Vérifiez et confirmez' }
];

// ═══════════════════════════════════════════════════════════════════════════
// UTILITAIRES
// ═══════════════════════════════════════════════════════════════════════════

function post(action, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${action}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    }).then(resp => resp.json()).catch(() => ({}));
}

function showNotification(message, type = 'info') {
    const notif = document.getElementById('notification');
    const icon = notif.querySelector('.notification-icon');
    const text = notif.querySelector('.notification-text');
    
    notif.className = `notification ${type}`;
    text.textContent = message;
    
    const icons = {
        success: 'fa-check-circle',
        error: 'fa-times-circle',
        warning: 'fa-exclamation-triangle',
        info: 'fa-info-circle'
    };
    
    icon.className = `notification-icon fas ${icons[type] || icons.info}`;
    notif.classList.remove('hidden');
    
    setTimeout(() => {
        notif.classList.add('hidden');
    }, 3000);
}

function hideAllContainers() {
    document.querySelectorAll('.container').forEach(c => c.classList.add('hidden'));
}

// ═══════════════════════════════════════════════════════════════════════════
// SÉLECTION DE PERSONNAGES
// ═══════════════════════════════════════════════════════════════════════════

function openSelection(data) {
    hideAllContainers();
    characters = data.characters || [];
    maxCharacters = data.maxCharacters || 3;
    
    renderCharacterGrid();
    document.getElementById('character-selection').classList.remove('hidden');
}

function renderCharacterGrid() {
    const grid = document.getElementById('characters-grid');
    grid.innerHTML = '';
    
    // Afficher les personnages existants
    characters.forEach(char => {
        const card = document.createElement('div');
        card.className = 'character-card';
        card.innerHTML = `
            <div class="character-info">
                <h3>${char.fullname}</h3>
                <p><i class="fas fa-briefcase"></i> ${char.job?.label || 'Chômeur'}</p>
                <p><i class="fas fa-birthday-cake"></i> ${char.age} ans</p>
                <p><i class="fas fa-${char.gender === 0 ? 'mars' : 'venus'}"></i> ${char.gender === 0 ? 'Homme' : 'Femme'}</p>
            </div>
            <div class="character-actions">
                <button class="btn btn-primary btn-select" data-citizenid="${char.citizenid}">
                    <i class="fas fa-play"></i> Jouer
                </button>
                <button class="btn btn-delete" data-citizenid="${char.citizenid}">
                    <i class="fas fa-trash"></i>
                </button>
            </div>
        `;
        grid.appendChild(card);
    });
    
    // Ajouter les slots vides
    for (let i = characters.length; i < maxCharacters; i++) {
        const emptyCard = document.createElement('div');
        emptyCard.className = 'character-card empty';
        emptyCard.innerHTML = `
            <i class="fas fa-plus"></i>
            <span>Créer un personnage</span>
        `;
        emptyCard.addEventListener('click', () => {
            post('newCharacter');
        });
        grid.appendChild(emptyCard);
    }
    
    // Event listeners pour les boutons
    document.querySelectorAll('.btn-select').forEach(btn => {
        btn.addEventListener('click', (e) => {
            e.stopPropagation();
            const citizenid = btn.dataset.citizenid;
            post('selectCharacter', { citizenid });
        });
    });
    
    document.querySelectorAll('.btn-delete').forEach(btn => {
        btn.addEventListener('click', (e) => {
            e.stopPropagation();
            const citizenid = btn.dataset.citizenid;
            if (confirm('Êtes-vous sûr de vouloir supprimer ce personnage ?')) {
                post('deleteCharacter', { citizenid });
            }
        });
    });
}

function closeSelection() {
    document.getElementById('character-selection').classList.add('hidden');
}

// ═══════════════════════════════════════════════════════════════════════════
// CRÉATEUR DE PERSONNAGE
// ═══════════════════════════════════════════════════════════════════════════

function openCreator(data) {
    hideAllContainers();
    
    isFirstTime = data.isFirstTime;
    currentSkin = data.skin || {};
    config = data.config || {};
    
    // Stocker les données de configuration
    window.creatorData = {
        parents: data.parents,
        hairColors: data.hairColors,
        eyeColors: data.eyeColors
    };
    
    currentStep = 0;
    renderProgressSteps();
    renderStep();
    updateNavigation();
    
    document.getElementById('character-creator').classList.remove('hidden');
}

function closeCreator() {
    document.getElementById('character-creator').classList.add('hidden');
}

function renderProgressSteps() {
    const container = document.getElementById('progress-steps');
    container.innerHTML = '';
    
    STEPS.forEach((step, index) => {
        const stepEl = document.createElement('div');
        stepEl.className = 'progress-step';
        stepEl.dataset.step = index;
        if (index === currentStep) stepEl.classList.add('active');
        if (index < currentStep) stepEl.classList.add('completed');
        stepEl.addEventListener('click', () => goToStep(index));
        container.appendChild(stepEl);
    });
    
    // Mettre à jour la barre de progression
    const fill = document.getElementById('progress-fill');
    fill.style.width = `${(currentStep / (STEPS.length - 1)) * 100}%`;
}

function renderStep() {
    const step = STEPS[currentStep];
    document.getElementById('step-title').textContent = step.title;
    document.getElementById('step-description').textContent = step.description;
    document.getElementById('step-indicator').textContent = `Étape ${currentStep + 1} / ${STEPS.length}`;
    
    const content = document.getElementById('panel-content');
    
    switch(step.id) {
        case 'gender':
            renderGenderStep(content);
            break;
        case 'morphology':
            renderMorphologyStep(content);
            break;
        case 'face':
            renderFaceStep(content);
            break;
        case 'hair':
            renderHairStep(content);
            break;
        case 'skin':
            renderSkinStep(content);
            break;
        case 'clothes':
            renderClothesStep(content);
            break;
        case 'identity':
            renderIdentityStep(content);
            break;
        case 'summary':
            renderSummaryStep(content);
            break;
    }
    
    // Informer le client du changement d'étape
    post('changeStep', { step: step.id });
}

function goToStep(index) {
    if (index >= 0 && index < STEPS.length) {
        currentStep = index;
        renderProgressSteps();
        renderStep();
        updateNavigation();
    }
}

function updateNavigation() {
    document.getElementById('btn-prev').disabled = currentStep === 0;
    
    const btnNext = document.getElementById('btn-next');
    if (currentStep === STEPS.length - 1) {
        btnNext.innerHTML = '<i class="fas fa-check"></i> Créer';
    } else {
        btnNext.innerHTML = 'Suivant <i class="fas fa-chevron-right"></i>';
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// ÉTAPES DU CRÉATEUR
// ═══════════════════════════════════════════════════════════════════════════

function renderGenderStep(container) {
    container.innerHTML = `
        <div class="gender-options">
            <div class="gender-option ${currentSkin.sex === 0 ? 'active' : ''}" data-sex="0">
                <i class="fas fa-mars"></i>
                <span>HOMME</span>
            </div>
            <div class="gender-option ${currentSkin.sex === 1 ? 'active' : ''}" data-sex="1">
                <i class="fas fa-venus"></i>
                <span>FEMME</span>
            </div>
        </div>
    `;
    
    container.querySelectorAll('.gender-option').forEach(opt => {
        opt.addEventListener('click', () => {
            container.querySelectorAll('.gender-option').forEach(o => o.classList.remove('active'));
            opt.classList.add('active');
            const sex = parseInt(opt.dataset.sex);
            currentSkin.sex = sex;
            post('changeSex', { sex });
        });
    });
}

function renderMorphologyStep(container) {
    const parents = window.creatorData.parents;
    
    container.innerHTML = `
        <div class="parent-select">
            <label>Mère</label>
            <div class="parent-options" id="mom-options">
                ${parents.female.map(p => `
                    <div class="parent-option ${currentSkin.mom === p.id ? 'active' : ''}" data-id="${p.id}">
                        ${p.name}
                    </div>
                `).join('')}
            </div>
        </div>
        
        <div class="parent-select">
            <label>Père</label>
            <div class="parent-options" id="dad-options">
                ${parents.male.map(p => `
                    <div class="parent-option ${currentSkin.dad === p.id ? 'active' : ''}" data-id="${p.id}">
                        ${p.name}
                    </div>
                `).join('')}
            </div>
        </div>
        
        <div class="control-group">
            <label>Ressemblance (Mère ↔ Père)</label>
            <div class="slider-control">
                <input type="range" min="0" max="100" value="${(currentSkin.mix || 0.5) * 100}" id="slider-mix">
                <span class="slider-value" id="value-mix">${Math.round((currentSkin.mix || 0.5) * 100)}%</span>
            </div>
        </div>
        
        <div class="control-group">
            <label>Teint (Mère ↔ Père)</label>
            <div class="slider-control">
                <input type="range" min="0" max="100" value="${(currentSkin.skinMix || 0.5) * 100}" id="slider-skinMix">
                <span class="slider-value" id="value-skinMix">${Math.round((currentSkin.skinMix || 0.5) * 100)}%</span>
            </div>
        </div>
    `;
    
    // Event listeners parents
    container.querySelectorAll('#mom-options .parent-option').forEach(opt => {
        opt.addEventListener('click', () => {
            container.querySelectorAll('#mom-options .parent-option').forEach(o => o.classList.remove('active'));
            opt.classList.add('active');
            currentSkin.mom = parseInt(opt.dataset.id);
            updateSkin('mom', currentSkin.mom);
        });
    });
    
    container.querySelectorAll('#dad-options .parent-option').forEach(opt => {
        opt.addEventListener('click', () => {
            container.querySelectorAll('#dad-options .parent-option').forEach(o => o.classList.remove('active'));
            opt.classList.add('active');
            currentSkin.dad = parseInt(opt.dataset.id);
            updateSkin('dad', currentSkin.dad);
        });
    });
    
    // Event listeners sliders
    setupSlider('mix', 0, 100, val => val / 100);
    setupSlider('skinMix', 0, 100, val => val / 100);
}

function renderFaceStep(container) {
    const faceFeatures = [
        { key: 'noseWidth', label: 'Largeur du nez' },
        { key: 'nosePeakHeight', label: 'Hauteur du nez' },
        { key: 'nosePeakLength', label: 'Longueur du nez' },
        { key: 'noseBoneHigh', label: 'Os nasal' },
        { key: 'nosePeakLowering', label: 'Pointe du nez' },
        { key: 'eyeBrowHeight', label: 'Hauteur des sourcils' },
        { key: 'eyeBrowLength', label: 'Longueur des sourcils' },
        { key: 'cheekBoneHeight', label: 'Hauteur des pommettes' },
        { key: 'cheekBoneWidth', label: 'Largeur des pommettes' },
        { key: 'cheekWidth', label: 'Largeur des joues' },
        { key: 'eyeOpenning', label: 'Ouverture des yeux' },
        { key: 'lipThickness', label: 'Épaisseur des lèvres' },
        { key: 'jawBoneWidth', label: 'Largeur de la mâchoire' },
        { key: 'jawBoneLength', label: 'Longueur de la mâchoire' },
        { key: 'chinBoneHeight', label: 'Hauteur du menton' },
        { key: 'chinBoneLength', label: 'Longueur du menton' },
        { key: 'chinBoneWidth', label: 'Largeur du menton' },
        { key: 'chinDimple', label: 'Fossette du menton' },
        { key: 'neckThickness', label: 'Épaisseur du cou' }
    ];
    
    container.innerHTML = faceFeatures.map(f => `
        <div class="control-group">
            <label>${f.label}</label>
            <div class="slider-control">
                <input type="range" min="-100" max="100" value="${(currentSkin[f.key] || 0) * 100}" id="slider-${f.key}">
                <span class="slider-value" id="value-${f.key}">${Math.round((currentSkin[f.key] || 0) * 100)}</span>
            </div>
        </div>
    `).join('');
    
    faceFeatures.forEach(f => {
        setupSlider(f.key, -100, 100, val => val / 100);
    });
}

function renderHairStep(container) {
    const hairColors = window.creatorData.hairColors;
    const isMale = currentSkin.sex === 0;
    
    container.innerHTML = `
        <div class="control-group">
            <label>Coupe de cheveux</label>
            <div class="slider-control">
                <input type="range" min="0" max="${isMale ? 36 : 38}" value="${currentSkin.hair || 0}" id="slider-hair">
                <span class="slider-value" id="value-hair">${currentSkin.hair || 0}</span>
            </div>
        </div>
        
        <div class="control-group">
            <label>Couleur principale</label>
            <div class="color-picker" id="hairColor-picker">
                ${hairColors.map(c => `
                    <div class="color-option ${currentSkin.hairColor === c.id ? 'active' : ''}" 
                         data-id="${c.id}" 
                         style="background-color: ${c.hex}"
                         title="${c.name}">
                    </div>
                `).join('')}
            </div>
        </div>
        
        <div class="control-group">
            <label>Mèches / Reflets</label>
            <div class="color-picker" id="hairHighlight-picker">
                ${hairColors.map(c => `
                    <div class="color-option ${currentSkin.hairHighlight === c.id ? 'active' : ''}" 
                         data-id="${c.id}" 
                         style="background-color: ${c.hex}"
                         title="${c.name}">
                    </div>
                `).join('')}
            </div>
        </div>
        
        ${isMale ? `
        <div class="control-group">
            <label>Barbe</label>
            <div class="slider-control">
                <input type="range" min="-1" max="28" value="${currentSkin.beard !== undefined ? currentSkin.beard : -1}" id="slider-beard">
                <span class="slider-value" id="value-beard">${currentSkin.beard !== undefined ? currentSkin.beard : -1}</span>
            </div>
        </div>
        
        <div class="control-group">
            <label>Couleur de barbe</label>
            <div class="color-picker" id="beardColor-picker">
                ${hairColors.map(c => `
                    <div class="color-option ${currentSkin.beardColor === c.id ? 'active' : ''}" 
                         data-id="${c.id}" 
                         style="background-color: ${c.hex}"
                         title="${c.name}">
                    </div>
                `).join('')}
            </div>
        </div>
        ` : ''}
        
        <div class="control-group">
            <label>Sourcils</label>
            <div class="slider-control">
                <input type="range" min="0" max="33" value="${currentSkin.eyebrows || 0}" id="slider-eyebrows">
                <span class="slider-value" id="value-eyebrows">${currentSkin.eyebrows || 0}</span>
            </div>
        </div>
        
        <div class="control-group">
            <label>Couleur des sourcils</label>
            <div class="color-picker" id="eyebrowsColor-picker">
                ${hairColors.map(c => `
                    <div class="color-option ${currentSkin.eyebrowsColor === c.id ? 'active' : ''}" 
                         data-id="${c.id}" 
                         style="background-color: ${c.hex}"
                         title="${c.name}">
                    </div>
                `).join('')}
            </div>
        </div>
    `;
    
    // Setup sliders
    setupSlider('hair', 0, isMale ? 36 : 38);
    if (isMale) setupSlider('beard', -1, 28);
    setupSlider('eyebrows', 0, 33);
    
    // Setup color pickers
    setupColorPicker('hairColor-picker', 'hairColor');
    setupColorPicker('hairHighlight-picker', 'hairHighlight');
    if (isMale) setupColorPicker('beardColor-picker', 'beardColor');
    setupColorPicker('eyebrowsColor-picker', 'eyebrowsColor');
}

function renderSkinStep(container) {
    const overlays = [
        { key: 'blemishes', label: 'Imperfections', max: 23 },
        { key: 'ageing', label: 'Vieillissement', max: 14 },
        { key: 'complexion', label: 'Teint', max: 11 },
        { key: 'sunDamage', label: 'Dégâts solaires', max: 10 },
        { key: 'moles', label: 'Grains de beauté', max: 17 }
    ];
    
    const isFemale = currentSkin.sex === 1;
    
    container.innerHTML = `
        ${overlays.map(o => `
            <div class="control-group">
                <label>${o.label}</label>
                <div class="slider-control">
                    <input type="range" min="-1" max="${o.max}" value="${currentSkin[o.key] !== undefined ? currentSkin[o.key] : -1}" id="slider-${o.key}">
                    <span class="slider-value" id="value-${o.key}">${currentSkin[o.key] !== undefined ? currentSkin[o.key] : -1}</span>
                </div>
            </div>
            <div class="control-group">
                <label>${o.label} - Opacité</label>
                <div class="slider-control">
                    <input type="range" min="0" max="100" value="${(currentSkin[o.key + 'Opacity'] || 1) * 100}" id="slider-${o.key}Opacity">
                    <span class="slider-value" id="value-${o.key}Opacity">${Math.round((currentSkin[o.key + 'Opacity'] || 1) * 100)}%</span>
                </div>
            </div>
        `).join('')}
        
        ${isFemale ? `
        <hr style="border-color: var(--color-border); margin: var(--spacing-lg) 0;">
        
        <div class="control-group">
            <label>Maquillage</label>
            <div class="slider-control">
                <input type="range" min="-1" max="74" value="${currentSkin.makeup !== undefined ? currentSkin.makeup : -1}" id="slider-makeup">
                <span class="slider-value" id="value-makeup">${currentSkin.makeup !== undefined ? currentSkin.makeup : -1}</span>
            </div>
        </div>
        
        <div class="control-group">
            <label>Rouge à lèvres</label>
            <div class="slider-control">
                <input type="range" min="-1" max="9" value="${currentSkin.lipstick !== undefined ? currentSkin.lipstick : -1}" id="slider-lipstick">
                <span class="slider-value" id="value-lipstick">${currentSkin.lipstick !== undefined ? currentSkin.lipstick : -1}</span>
            </div>
        </div>
        
        <div class="control-group">
            <label>Blush</label>
            <div class="slider-control">
                <input type="range" min="-1" max="6" value="${currentSkin.blush !== undefined ? currentSkin.blush : -1}" id="slider-blush">
                <span class="slider-value" id="value-blush">${currentSkin.blush !== undefined ? currentSkin.blush : -1}</span>
            </div>
        </div>
        ` : ''}
        
        <hr style="border-color: var(--color-border); margin: var(--spacing-lg) 0;">
        
        <div class="control-group">
            <label>Couleur des yeux</label>
            <div class="color-picker" id="eyeColor-picker">
                ${window.creatorData.eyeColors.map(c => `
                    <div class="color-option ${currentSkin.eyeColor === c.id ? 'active' : ''}" 
                         data-id="${c.id}" 
                         style="background-color: ${c.hex}"
                         title="${c.name}">
                    </div>
                `).join('')}
            </div>
        </div>
    `;
    
    // Setup sliders
    overlays.forEach(o => {
        setupSlider(o.key, -1, o.max);
        setupSlider(o.key + 'Opacity', 0, 100, val => val / 100);
    });
    
    if (isFemale) {
        setupSlider('makeup', -1, 74);
        setupSlider('lipstick', -1, 9);
        setupSlider('blush', -1, 6);
    }
    
    setupColorPicker('eyeColor-picker', 'eyeColor');
}

function renderClothesStep(container) {
    const isMale = currentSkin.sex === 0;
    
    container.innerHTML = `
        <div class="control-group">
            <label>Haut</label>
            <div class="slider-control">
                <input type="range" min="0" max="200" value="${currentSkin.torso || 0}" id="slider-torso">
                <span class="slider-value" id="value-torso">${currentSkin.torso || 0}</span>
            </div>
        </div>
        
        <div class="control-group">
            <label>Texture du haut</label>
            <div class="slider-control">
                <input type="range" min="0" max="15" value="${currentSkin.torsoTexture || 0}" id="slider-torsoTexture">
                <span class="slider-value" id="value-torsoTexture">${currentSkin.torsoTexture || 0}</span>
            </div>
        </div>
        
        <div class="control-group">
            <label>Sous-vêtement</label>
            <div class="slider-control">
                <input type="range" min="0" max="200" value="${currentSkin.tshirt || 0}" id="slider-tshirt">
                <span class="slider-value" id="value-tshirt">${currentSkin.tshirt || 0}</span>
            </div>
        </div>
        
        <div class="control-group">
            <label>Pantalon</label>
            <div class="slider-control">
                <input type="range" min="0" max="150" value="${currentSkin.pants || 0}" id="slider-pants">
                <span class="slider-value" id="value-pants">${currentSkin.pants || 0}</span>
            </div>
        </div>
        
        <div class="control-group">
            <label>Texture pantalon</label>
            <div class="slider-control">
                <input type="range" min="0" max="15" value="${currentSkin.pantsTexture || 0}" id="slider-pantsTexture">
                <span class="slider-value" id="value-pantsTexture">${currentSkin.pantsTexture || 0}</span>
            </div>
        </div>
        
        <div class="control-group">
            <label>Chaussures</label>
            <div class="slider-control">
                <input type="range" min="0" max="100" value="${currentSkin.shoes || 0}" id="slider-shoes">
                <span class="slider-value" id="value-shoes">${currentSkin.shoes || 0}</span>
            </div>
        </div>
        
        <div class="control-group">
            <label>Texture chaussures</label>
            <div class="slider-control">
                <input type="range" min="0" max="15" value="${currentSkin.shoesTexture || 0}" id="slider-shoesTexture">
                <span class="slider-value" id="value-shoesTexture">${currentSkin.shoesTexture || 0}</span>
            </div>
        </div>
    `;
    
    // Setup sliders
    setupSlider('torso', 0, 200);
    setupSlider('torsoTexture', 0, 15);
    setupSlider('tshirt', 0, 200);
    setupSlider('pants', 0, 150);
    setupSlider('pantsTexture', 0, 15);
    setupSlider('shoes', 0, 100);
    setupSlider('shoesTexture', 0, 15);
}

function renderIdentityStep(container) {
    container.innerHTML = `
        <div class="input-group">
            <label>Prénom *</label>
            <input type="text" id="input-firstname" maxlength="${config.maxNameLength || 20}" 
                   placeholder="Entrez votre prénom" value="${currentSkin.firstname || ''}">
        </div>
        
        <div class="input-group">
            <label>Nom de famille *</label>
            <input type="text" id="input-lastname" maxlength="${config.maxNameLength || 20}" 
                   placeholder="Entrez votre nom" value="${currentSkin.lastname || ''}">
        </div>
        
        <div class="input-group">
            <label>Âge *</label>
            <input type="number" id="input-age" min="${config.minAge || 18}" max="${config.maxAge || 80}" 
                   placeholder="${config.minAge || 18} - ${config.maxAge || 80}" value="${currentSkin.age || 25}">
        </div>
        
        <div class="input-group">
            <label>Nationalité</label>
            <select id="input-nationality">
                <option value="Américain" ${currentSkin.nationality === 'Américain' ? 'selected' : ''}>Américain</option>
                <option value="Français" ${currentSkin.nationality === 'Français' ? 'selected' : ''}>Français</option>
                <option value="Anglais" ${currentSkin.nationality === 'Anglais' ? 'selected' : ''}>Anglais</option>
                <option value="Espagnol" ${currentSkin.nationality === 'Espagnol' ? 'selected' : ''}>Espagnol</option>
                <option value="Italien" ${currentSkin.nationality === 'Italien' ? 'selected' : ''}>Italien</option>
                <option value="Allemand" ${currentSkin.nationality === 'Allemand' ? 'selected' : ''}>Allemand</option>
                <option value="Mexicain" ${currentSkin.nationality === 'Mexicain' ? 'selected' : ''}>Mexicain</option>
                <option value="Canadien" ${currentSkin.nationality === 'Canadien' ? 'selected' : ''}>Canadien</option>
                <option value="Autre" ${currentSkin.nationality === 'Autre' ? 'selected' : ''}>Autre</option>
            </select>
        </div>
        
        <div class="input-group">
            <label>Histoire (optionnel)</label>
            <textarea id="input-story" maxlength="${config.maxStoryLength || 500}" 
                      placeholder="Racontez l'histoire de votre personnage...">${currentSkin.story || ''}</textarea>
            <div class="char-count"><span id="story-count">0</span> / ${config.maxStoryLength || 500}</div>
        </div>
    `;
    
    // Event listeners
    document.getElementById('input-firstname').addEventListener('input', (e) => {
        currentSkin.firstname = e.target.value;
    });
    
    document.getElementById('input-lastname').addEventListener('input', (e) => {
        currentSkin.lastname = e.target.value;
    });
    
    document.getElementById('input-age').addEventListener('input', (e) => {
        currentSkin.age = parseInt(e.target.value);
    });
    
    document.getElementById('input-nationality').addEventListener('change', (e) => {
        currentSkin.nationality = e.target.value;
    });
    
    const storyInput = document.getElementById('input-story');
    storyInput.addEventListener('input', (e) => {
        currentSkin.story = e.target.value;
        document.getElementById('story-count').textContent = e.target.value.length;
    });
    document.getElementById('story-count').textContent = (currentSkin.story || '').length;
}

function renderSummaryStep(container) {
    container.innerHTML = `
        <div class="summary-container">
            <div class="summary-item">
                <span class="summary-label">Nom complet</span>
                <span class="summary-value">${currentSkin.firstname || '?'} ${currentSkin.lastname || '?'}</span>
            </div>
            <div class="summary-item">
                <span class="summary-label">Âge</span>
                <span class="summary-value">${currentSkin.age || '?'} ans</span>
            </div>
            <div class="summary-item">
                <span class="summary-label">Sexe</span>
                <span class="summary-value">${currentSkin.sex === 0 ? 'Homme' : 'Femme'}</span>
            </div>
            <div class="summary-item">
                <span class="summary-label">Nationalité</span>
                <span class="summary-value">${currentSkin.nationality || 'Américain'}</span>
            </div>
        </div>
        
        <button class="btn btn-primary btn-glow btn-save" id="btn-save">
            <i class="fas fa-save"></i> CRÉER LE PERSONNAGE
        </button>
    `;
    
    document.getElementById('btn-save').addEventListener('click', saveCharacter);
}

// ═══════════════════════════════════════════════════════════════════════════
// HELPERS UI
// ═══════════════════════════════════════════════════════════════════════════

function setupSlider(key, min, max, transform = val => val) {
    const slider = document.getElementById(`slider-${key}`);
    const valueEl = document.getElementById(`value-${key}`);
    
    if (!slider || !valueEl) return;
    
    slider.addEventListener('input', () => {
        const rawValue = parseInt(slider.value);
        const transformedValue = transform(rawValue);
        
        currentSkin[key] = transformedValue;
        valueEl.textContent = key.includes('Opacity') || key.includes('mix') || key.includes('Mix') 
            ? Math.round(transformedValue * 100) + '%' 
            : rawValue;
        
        updateSkin(key, transformedValue);
    });
}

function setupColorPicker(pickerId, key) {
    const picker = document.getElementById(pickerId);
    if (!picker) return;
    
    picker.querySelectorAll('.color-option').forEach(opt => {
        opt.addEventListener('click', () => {
            picker.querySelectorAll('.color-option').forEach(o => o.classList.remove('active'));
            opt.classList.add('active');
            const id = parseInt(opt.dataset.id);
            currentSkin[key] = id;
            updateSkin(key, id);
        });
    });
}

function updateSkin(key, value) {
    post('updateSkin', { key, value });
}

function saveCharacter() {
    // Validation
    if (!currentSkin.firstname || currentSkin.firstname.length < (config.minNameLength || 2)) {
        showNotification('Prénom invalide (minimum ' + (config.minNameLength || 2) + ' caractères)', 'error');
        return;
    }
    
    if (!currentSkin.lastname || currentSkin.lastname.length < (config.minNameLength || 2)) {
        showNotification('Nom invalide (minimum ' + (config.minNameLength || 2) + ' caractères)', 'error');
        return;
    }
    
    if (!currentSkin.age || currentSkin.age < (config.minAge || 18) || currentSkin.age > (config.maxAge || 80)) {
        showNotification('Âge invalide', 'error');
        return;
    }
    
    post('saveCharacter', {
        firstname: currentSkin.firstname,
        lastname: currentSkin.lastname,
        age: currentSkin.age,
        nationality: currentSkin.nationality || 'Américain',
        story: currentSkin.story || ''
    }).then(result => {
        if (result.success) {
            showNotification('Personnage créé avec succès!', 'success');
        } else {
            showNotification(result.error || 'Erreur lors de la création', 'error');
        }
    });
}

// ═══════════════════════════════════════════════════════════════════════════
// SHOPS
// ═══════════════════════════════════════════════════════════════════════════

function openShop(data) {
    hideAllContainers();
    currentShopType = data.type;
    shopData = data;
    
    switch(data.type) {
        case 'clothing':
            openClothingShop(data);
            break;
        case 'barber':
            openBarberShop(data);
            break;
        case 'surgery':
            openSurgeryShop(data);
            break;
    }
}

function openClothingShop(data) {
    document.getElementById('shop-name').textContent = data.shop.name.toUpperCase();
    document.getElementById('money-cash').textContent = data.money.cash || 0;
    document.getElementById('money-bank').textContent = data.money.bank || 0;
    
    // Rendre les catégories
    const categoriesContainer = document.getElementById('shop-categories');
    categoriesContainer.innerHTML = '';
    
    data.shop.categories.forEach((catId, index) => {
        const cat = data.categories[catId];
        if (!cat) return;
        
        const btn = document.createElement('button');
        btn.className = `category-btn ${index === 0 ? 'active' : ''}`;
        btn.dataset.category = catId;
        btn.innerHTML = `<i class="fas ${cat.icon}"></i> ${cat.label}`;
        btn.addEventListener('click', () => selectCategory(catId, cat, data.shop.prices[catId]));
        categoriesContainer.appendChild(btn);
    });
    
    // Sélectionner la première catégorie
    if (data.shop.categories.length > 0) {
        const firstCat = data.shop.categories[0];
        selectCategory(firstCat, data.categories[firstCat], data.shop.prices[firstCat]);
    }
    
    document.getElementById('clothing-shop').classList.remove('hidden');
}

function selectCategory(catId, category, price) {
    document.querySelectorAll('.category-btn').forEach(b => b.classList.remove('active'));
    document.querySelector(`[data-category="${catId}"]`)?.classList.add('active');
    
    shopData.currentCategory = catId;
    shopData.currentPrice = price;
    
    document.getElementById('item-price').textContent = '$' + price;
    
    // Reset valeurs
    shopData.currentDrawable = 0;
    shopData.currentTexture = 0;
    
    updateClothingDisplay();
}

function updateClothingDisplay() {
    document.getElementById('drawable-value').textContent = `${shopData.currentDrawable} / ?`;
    document.getElementById('texture-value').textContent = `${shopData.currentTexture} / ?`;
    
    // Obtenir les variations disponibles
    const category = shopData.categories[shopData.currentCategory];
    if (category.components) {
        post('getShopVariations', { 
            component: category.components[0].component,
            drawable: shopData.currentDrawable 
        }).then(result => {
            document.getElementById('drawable-value').textContent = 
                `${shopData.currentDrawable} / ${result.drawableCount - 1}`;
            document.getElementById('texture-value').textContent = 
                `${shopData.currentTexture} / ${result.textureCount - 1}`;
            
            shopData.maxDrawable = result.drawableCount - 1;
            shopData.maxTexture = result.textureCount - 1;
        });
    }
}

function openBarberShop(data) {
    document.getElementById('barber-name').textContent = data.shop.name.toUpperCase();
    document.getElementById('barber-money-cash').textContent = data.money.cash || 0;
    
    shopData = data;
    renderBarberTab('hair');
    
    document.getElementById('barber-shop').classList.remove('hidden');
}

function renderBarberTab(tab) {
    const container = document.getElementById('barber-options');
    
    switch(tab) {
        case 'hair':
            container.innerHTML = `
                <div class="control-group">
                    <label>Coupe</label>
                    <div class="slider-container">
                        <button class="btn-slider" onclick="changeBarberValue('hair', -1)"><i class="fas fa-minus"></i></button>
                        <span id="barber-hair-value">0 / ${shopData.maxHair}</span>
                        <button class="btn-slider" onclick="changeBarberValue('hair', 1)"><i class="fas fa-plus"></i></button>
                    </div>
                </div>
                <div class="control-group">
                    <label>Couleur</label>
                    <div class="color-picker" id="barber-hairColor">
                        ${shopData.hairColors.map(c => `
                            <div class="color-option" data-id="${c.id}" style="background-color: ${c.hex}" title="${c.name}"></div>
                        `).join('')}
                    </div>
                </div>
            `;
            break;
        case 'beard':
            container.innerHTML = `
                <div class="control-group">
                    <label>Style</label>
                    <div class="slider-container">
                        <button class="btn-slider" onclick="changeBarberValue('beard', -1)"><i class="fas fa-minus"></i></button>
                        <span id="barber-beard-value">-1 / ${shopData.maxBeard}</span>
                        <button class="btn-slider" onclick="changeBarberValue('beard', 1)"><i class="fas fa-plus"></i></button>
                    </div>
                </div>
            `;
            break;
        case 'eyebrows':
            container.innerHTML = `
                <div class="control-group">
                    <label>Style</label>
                    <div class="slider-container">
                        <button class="btn-slider" onclick="changeBarberValue('eyebrows', -1)"><i class="fas fa-minus"></i></button>
                        <span id="barber-eyebrows-value">0 / ${shopData.maxEyebrows}</span>
                        <button class="btn-slider" onclick="changeBarberValue('eyebrows', 1)"><i class="fas fa-plus"></i></button>
                    </div>
                </div>
            `;
            break;
    }
}

function openSurgeryShop(data) {
    document.getElementById('surgery-money').textContent = data.money.bank || 0;
    document.getElementById('surgery-price').textContent = data.shop.price;
    
    shopData = data;
    renderSurgeryTab('heritage');
    
    document.getElementById('surgery-shop').classList.remove('hidden');
}

function renderSurgeryTab(tab) {
    const container = document.getElementById('surgery-options');
    // Contenu similaire aux étapes du créateur
    container.innerHTML = '<p style="color: var(--color-text-muted);">Utilisez les contrôles pour modifier votre apparence.</p>';
}

function closeShop() {
    document.querySelectorAll('.container').forEach(c => c.classList.add('hidden'));
    currentShopType = null;
}

// ═══════════════════════════════════════════════════════════════════════════
// EVENT LISTENERS
// ═══════════════════════════════════════════════════════════════════════════

// Navigation créateur
document.getElementById('btn-prev')?.addEventListener('click', () => {
    if (currentStep > 0) {
        goToStep(currentStep - 1);
    }
});

document.getElementById('btn-next')?.addEventListener('click', () => {
    if (currentStep < STEPS.length - 1) {
        goToStep(currentStep + 1);
    } else {
        saveCharacter();
    }
});

document.getElementById('btn-reset')?.addEventListener('click', () => {
    post('reset').then(result => {
        if (result.success) {
            currentSkin = result.skin;
            renderStep();
            showNotification('Apparence réinitialisée', 'info');
        }
    });
});

document.getElementById('btn-random')?.addEventListener('click', () => {
    post('randomize').then(result => {
        if (result.success) {
            currentSkin = result.skin;
            renderStep();
            showNotification('Apparence aléatoire générée', 'info');
        }
    });
});

// Rotation personnage
document.getElementById('btn-rotate-left')?.addEventListener('click', () => {
    post('rotatePed', { direction: -1 });
});

document.getElementById('btn-rotate-right')?.addEventListener('click', () => {
    post('rotatePed', { direction: 1 });
});

// Nouveau personnage
document.getElementById('btn-new-character')?.addEventListener('click', () => {
    post('newCharacter');
});

// Shop clothing
document.getElementById('btn-drawable-prev')?.addEventListener('click', () => {
    if (shopData.currentDrawable > 0) {
        shopData.currentDrawable--;
        tryClothing();
    }
});

document.getElementById('btn-drawable-next')?.addEventListener('click', () => {
    if (shopData.currentDrawable < shopData.maxDrawable) {
        shopData.currentDrawable++;
        tryClothing();
    }
});

document.getElementById('btn-texture-prev')?.addEventListener('click', () => {
    if (shopData.currentTexture > 0) {
        shopData.currentTexture--;
        tryClothing();
    }
});

document.getElementById('btn-texture-next')?.addEventListener('click', () => {
    if (shopData.currentTexture < shopData.maxTexture) {
        shopData.currentTexture++;
        tryClothing();
    }
});

function tryClothing() {
    const category = shopData.categories[shopData.currentCategory];
    if (category.components) {
        post('tryClothing', {
            component: category.components[0].component,
            drawable: shopData.currentDrawable,
            texture: shopData.currentTexture
        });
    } else if (category.props) {
        post('tryClothing', {
            prop: category.props[0].prop,
            drawable: shopData.currentDrawable,
            texture: shopData.currentTexture
        });
    }
    updateClothingDisplay();
}

document.getElementById('btn-shop-buy')?.addEventListener('click', () => {
    const category = shopData.categories[shopData.currentCategory];
    post('buyClothing', {
        category: shopData.currentCategory,
        component: category.components ? category.components[0].component : null,
        prop: category.props ? category.props[0].prop : null,
        drawable: shopData.currentDrawable,
        texture: shopData.currentTexture,
        paymentType: 'cash'
    }).then(result => {
        if (result.success) {
            showNotification('Achat effectué!', 'success');
        } else {
            showNotification(result.error || 'Échec de l\'achat', 'error');
        }
    });
});

document.getElementById('btn-shop-cancel')?.addEventListener('click', () => {
    post('cancelChanges');
    post('closeShop', { cancelled: true });
});

document.getElementById('btn-close-shop')?.addEventListener('click', () => {
    post('cancelChanges');
    post('closeShop', { cancelled: true });
});

// Shop rotations
document.getElementById('btn-shop-rotate-left')?.addEventListener('click', () => {
    post('shopRotatePed', { direction: -1 });
});

document.getElementById('btn-shop-rotate-right')?.addEventListener('click', () => {
    post('shopRotatePed', { direction: 1 });
});

// Barber
document.querySelectorAll('.barber-tabs .tab-btn')?.forEach(btn => {
    btn.addEventListener('click', () => {
        document.querySelectorAll('.barber-tabs .tab-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        renderBarberTab(btn.dataset.tab);
    });
});

document.getElementById('btn-barber-cancel')?.addEventListener('click', () => {
    post('cancelChanges');
    post('closeShop', { cancelled: true });
});

document.getElementById('btn-close-barber')?.addEventListener('click', () => {
    post('cancelChanges');
    post('closeShop', { cancelled: true });
});

// Surgery
document.querySelectorAll('.surgery-tabs .tab-btn')?.forEach(btn => {
    btn.addEventListener('click', () => {
        document.querySelectorAll('.surgery-tabs .tab-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        renderSurgeryTab(btn.dataset.tab);
    });
});

document.getElementById('btn-surgery-cancel')?.addEventListener('click', () => {
    post('cancelChanges');
    post('closeShop', { cancelled: true });
});

document.getElementById('btn-close-surgery')?.addEventListener('click', () => {
    post('cancelChanges');
    post('closeShop', { cancelled: true });
});

// Escape key
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        post('close');
    }
});

// ═══════════════════════════════════════════════════════════════════════════
// NUI MESSAGE HANDLER
// ═══════════════════════════════════════════════════════════════════════════

window.addEventListener('message', (event) => {
    const data = event.data;
    
    switch(data.action) {
        case 'openCreator':
            openCreator(data.data);
            break;
        case 'closeCreator':
            closeCreator();
            break;
        case 'openSelection':
            openSelection(data.data);
            break;
        case 'closeSelection':
            closeSelection();
            break;
        case 'updateCharacters':
            characters = data.data.characters || [];
            maxCharacters = data.data.maxCharacters || 3;
            renderCharacterGrid();
            break;
        case 'openShop':
            openShop(data.data);
            break;
        case 'closeShop':
            closeShop();
            break;
        case 'updateMoney':
            if (document.getElementById('money-cash')) {
                document.getElementById('money-cash').textContent = data.data.cash || 0;
            }
            if (document.getElementById('money-bank')) {
                document.getElementById('money-bank').textContent = data.data.bank || 0;
            }
            if (document.getElementById('barber-money-cash')) {
                document.getElementById('barber-money-cash').textContent = data.data.cash || 0;
            }
            if (document.getElementById('surgery-money')) {
                document.getElementById('surgery-money').textContent = data.data.bank || 0;
            }
            break;
    }
});
