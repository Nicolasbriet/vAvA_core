// ========================================
// vAvA EMS - JAVASCRIPT
// ========================================

window.addEventListener('message', function(event) {
    const data = event.data;
    
    switch(data.action) {
        case 'updateVitals':
            updateVitalSigns(data.data);
            break;
        case 'openEMSMenu':
            openEMSMenu(data.data);
            break;
        case 'openDiagnosis':
            openDiagnosisMenu(data.data);
            break;
        case 'showVitalsHUD':
            document.getElementById('vitals-hud').classList.remove('hidden');
            break;
        case 'hideVitalsHUD':
            document.getElementById('vitals-hud').classList.add('hidden');
            break;
    }
});

// ========================================
// SIGNES VITAUX HUD
// ========================================

function updateVitalSigns(vitals) {
    if (!vitals) return;
    
    // Pouls
    const pulse = Math.round(vitals.pulse || 75);
    document.getElementById('pulse-value').textContent = pulse;
    document.getElementById('pulse-bar').style.width = (pulse / 180 * 100) + '%';
    
    // Tension artérielle
    document.getElementById('bp-systolic').textContent = Math.round(vitals.bloodPressureSystolic || 120);
    document.getElementById('bp-diastolic').textContent = Math.round(vitals.bloodPressureDiastolic || 80);
    
    // Oxygène
    const oxygen = Math.round(vitals.oxygenSaturation || 98);
    document.getElementById('oxygen-value').textContent = oxygen;
    document.getElementById('oxygen-bar').style.width = oxygen + '%';
    
    // Volume sanguin
    const bloodVolume = Math.round(vitals.bloodVolume || 100);
    document.getElementById('blood-volume-value').textContent = bloodVolume;
    document.getElementById('blood-volume-bar').style.width = bloodVolume + '%';
    
    // Température
    document.getElementById('temperature-value').textContent = (vitals.temperature || 37.0).toFixed(1);
    
    // Douleur
    const pain = Math.round(vitals.painLevel || 0);
    document.getElementById('pain-value').textContent = pain;
    document.getElementById('pain-bar').style.width = (pain / 10 * 100) + '%';
    
    // Statut global
    updatePatientStatus(vitals);
}

function updatePatientStatus(vitals) {
    const statusElement = document.getElementById('patient-status');
    
    if (vitals.bloodVolume < 30 || vitals.pulse < 50 || vitals.pulse > 150) {
        statusElement.textContent = 'CRITIQUE';
        statusElement.classList.add('critical');
    } else if (vitals.bloodVolume < 60 || vitals.oxygenSaturation < 90 || vitals.painLevel > 7) {
        statusElement.textContent = 'INSTABLE';
        statusElement.classList.add('critical');
    } else if (vitals.bloodVolume < 80 || vitals.painLevel > 4) {
        statusElement.textContent = 'MODÉRÉ';
        statusElement.classList.remove('critical');
    } else {
        statusElement.textContent = 'STABLE';
        statusElement.classList.remove('critical');
    }
}

// ========================================
// MENU EMS PRINCIPAL
// ========================================

function openEMSMenu(data) {
    const menu = document.getElementById('ems-menu');
    menu.classList.remove('hidden');
    
    // Charger le stock de sang
    if (data.bloodStock) {
        loadBloodStock(data.bloodStock);
    } else {
        // Demander le stock au serveur
        fetch(`https://${GetParentResourceName()}/getBloodStock`, {
            method: 'POST',
            body: JSON.stringify({})
        }).then(resp => resp.json()).then(stock => {
            loadBloodStock(stock);
        });
    }
    
    // Charger le nombre d'appels d'urgence
    fetch(`https://${GetParentResourceName()}/getEmergencyCallsCount`, {
        method: 'POST',
        body: JSON.stringify({})
    }).then(resp => resp.json()).then(data => {
        document.getElementById('calls-count').textContent = data.count || 0;
    });
}

function closeMenu() {
    document.getElementById('ems-menu').classList.add('hidden');
    
    fetch(`https://${GetParentResourceName()}/close`, {
        method: 'POST',
        body: JSON.stringify({})
    });
}

function loadBloodStock(stock) {
    const container = document.getElementById('blood-stock');
    container.innerHTML = '';
    
    const bloodTypes = ['O-', 'O+', 'A-', 'A+', 'B-', 'B+', 'AB-', 'AB+'];
    
    bloodTypes.forEach(type => {
        const units = stock[type] || 0;
        const item = document.createElement('div');
        item.className = 'blood-stock-item';
        
        if (units < 5) {
            item.classList.add('critical');
        } else if (units < 10) {
            item.classList.add('low');
        }
        
        item.innerHTML = `
            <div class="blood-type">${type}</div>
            <div class="blood-units">${units}</div>
            <div class="blood-label">Unités</div>
        `;
        
        container.appendChild(item);
    });
}

// ========================================
// MENU DIAGNOSTIC
// ========================================

let currentPatient = null;

function openDiagnosisMenu(patientData) {
    currentPatient = patientData;
    const menu = document.getElementById('diagnosis-menu');
    menu.classList.remove('hidden');
    
    // Remplir les informations
    document.getElementById('patient-name').textContent = patientData.name || 'Inconnu';
    document.getElementById('patient-blood-type').textContent = patientData.bloodType || '?';
    
    // Signes vitaux
    const vitalsContainer = document.getElementById('diagnosis-vitals');
    vitalsContainer.innerHTML = `
        <p><strong>Pouls :</strong> ${Math.round(patientData.vitalSigns.pulse)} BPM</p>
        <p><strong>Tension :</strong> ${Math.round(patientData.vitalSigns.bloodPressureSystolic)}/${Math.round(patientData.vitalSigns.bloodPressureDiastolic)} mmHg</p>
        <p><strong>Saturation O₂ :</strong> ${Math.round(patientData.vitalSigns.oxygenSaturation)}%</p>
        <p><strong>Volume sanguin :</strong> ${Math.round(patientData.vitalSigns.bloodVolume)}%</p>
        <p><strong>Température :</strong> ${patientData.vitalSigns.temperature.toFixed(1)}°C</p>
        <p><strong>Douleur :</strong> ${Math.round(patientData.vitalSigns.painLevel)}/10</p>
    `;
    
    // Blessures
    const injuriesContainer = document.getElementById('diagnosis-injuries');
    injuriesContainer.innerHTML = '';
    
    if (patientData.injuries && patientData.injuries.length > 0) {
        patientData.injuries.forEach(injury => {
            const injuryItem = document.createElement('div');
            injuryItem.className = 'injury-item';
            injuryItem.innerHTML = `
                <div class="injury-type">${formatInjuryType(injury.type)}</div>
                <div class="injury-details">
                    Localisation: ${formatBodyPart(injury.bodyPart)} | 
                    Sévérité: ${getSeverityLabel(injury.severity)}
                </div>
            `;
            injuriesContainer.appendChild(injuryItem);
        });
    } else {
        injuriesContainer.innerHTML = '<p style="color: #999;">Aucune blessure détectée</p>';
    }
}

function closeDiagnosis() {
    document.getElementById('diagnosis-menu').classList.add('hidden');
    currentPatient = null;
    
    fetch(`https://${GetParentResourceName()}/close`, {
        method: 'POST',
        body: JSON.stringify({})
    });
}

// ========================================
// ACTIONS
// ========================================

function viewEmergencyCalls() {
    fetch(`https://${GetParentResourceName()}/viewEmergencyCalls`, {
        method: 'POST',
        body: JSON.stringify({})
    });
}

function diagnoseNearestPatient() {
    fetch(`https://${GetParentResourceName()}/diagnoseNearestPatient`, {
        method: 'POST',
        body: JSON.stringify({})
    });
    closeMenu();
}

function spawnVehicle(vehicleType) {
    fetch(`https://${GetParentResourceName()}/spawnVehicle`, {
        method: 'POST',
        body: JSON.stringify({ vehicle: vehicleType })
    });
    closeMenu();
}

function openEquipmentMenu() {
    fetch(`https://${GetParentResourceName()}/openEquipmentMenu`, {
        method: 'POST',
        body: JSON.stringify({})
    });
}

function performCPR() {
    fetch(`https://${GetParentResourceName()}/performCPR`, {
        method: 'POST',
        body: JSON.stringify({})
    });
    closeMenu();
}

function treatPatient() {
    if (!currentPatient) return;
    
    fetch(`https://${GetParentResourceName()}/treatPatient`, {
        method: 'POST',
        body: JSON.stringify({ target: currentPatient.id })
    });
    closeDiagnosis();
}

function transfusePatient() {
    if (!currentPatient) return;
    
    // Demander le type de sang
    const bloodType = prompt('Type de sang à transfuser:', currentPatient.bloodType);
    
    if (bloodType) {
        fetch(`https://${GetParentResourceName()}/transfuseBlood`, {
            method: 'POST',
            body: JSON.stringify({ 
                target: currentPatient.id,
                bloodType: bloodType
            })
        });
        closeDiagnosis();
    }
}

function revivePatient() {
    if (!currentPatient) return;
    
    fetch(`https://${GetParentResourceName()}/revivePatient`, {
        method: 'POST',
        body: JSON.stringify({ target: currentPatient.id })
    });
    closeDiagnosis();
}

// ========================================
// FORMATAGE
// ========================================

function formatInjuryType(type) {
    const labels = {
        'contusion': 'Contusion',
        'open_wound': 'Plaie ouverte',
        'simple_fracture': 'Fracture simple',
        'open_fracture': 'Fracture ouverte',
        'gunshot_entry': 'Blessure par balle (entrée)',
        'gunshot_exit': 'Blessure par balle (sortie)',
        'burn_first': 'Brûlure 1er degré',
        'burn_second': 'Brûlure 2e degré',
        'burn_third': 'Brûlure 3e degré',
        'head_trauma': 'Traumatisme crânien',
        'internal_injury': 'Lésion interne',
        'internal_bleeding': 'Hémorragie interne'
    };
    return labels[type] || type;
}

function formatBodyPart(part) {
    const labels = {
        'head': 'Tête',
        'neck': 'Cou',
        'chest': 'Torse',
        'abdomen': 'Abdomen',
        'left_arm': 'Bras gauche',
        'right_arm': 'Bras droit',
        'left_leg': 'Jambe gauche',
        'right_leg': 'Jambe droite'
    };
    return labels[part] || part;
}

function getSeverityLabel(severity) {
    const labels = {
        1: 'Légère',
        2: 'Modérée',
        3: 'Sévère',
        4: 'Critique'
    };
    return labels[severity] || 'Inconnue';
}

// ========================================
// UTILITAIRES
// ========================================

function GetParentResourceName() {
    const url = window.location.href;
    const match = url.match(/https?:\/\/cfx-nui-([^\/]+)/);
    return match ? match[1] : 'vAvA_ems';
}

// Fermer avec Échap
document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape') {
        const emsMenu = document.getElementById('ems-menu');
        const diagnosisMenu = document.getElementById('diagnosis-menu');
        
        if (!emsMenu.classList.contains('hidden')) {
            closeMenu();
        }
        
        if (!diagnosisMenu.classList.contains('hidden')) {
            closeDiagnosis();
        }
    }
});
