// ══════════════════════════════════════════════════════════════════════════════
// vAvA Economy Dashboard - JavaScript
// ══════════════════════════════════════════════════════════════════════════════

let economyData = {
    state: {},
    items: [],
    jobs: [],
    logs: []
};

// ══════════════════════════════════════════════════════════════════════════════
// NUI Message Listener
// ══════════════════════════════════════════════════════════════════════════════

window.addEventListener('message', function(event) {
    const data = event.data;
    
    switch(data.action) {
        case 'openDashboard':
            economyData = data;
            openDashboard();
            break;
        case 'closeDashboard':
            closeDashboard();
            break;
    }
});

// ══════════════════════════════════════════════════════════════════════════════
// Ouvrir le dashboard
// ══════════════════════════════════════════════════════════════════════════════

function openDashboard() {
    $('#economyDashboard').fadeIn(300);
    updateOverview();
    renderItems();
    renderJobs();
    renderTaxes();
    renderLogs();
    initCharts();
}

// ══════════════════════════════════════════════════════════════════════════════
// Fermer le dashboard
// ══════════════════════════════════════════════════════════════════════════════

function closeDashboard() {
    $('#economyDashboard').fadeOut(300);
    
    // Utiliser fetch() au lieu de $.post() pour \u00e9viter les probl\u00e8mes
    fetch('https://economy/close', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    }).catch(err => console.error('Error closing dashboard:', err));
}

// ══════════════════════════════════════════════════════════════════════════════
// Mettre à jour l'overview
// ══════════════════════════════════════════════════════════════════════════════

function updateOverview() {
    const state = economyData.state;
    
    $('#stat-inflation').text(state.inflation?.toFixed(4) || '1.0000');
    $('#stat-multiplier').text(state.baseMultiplier?.toFixed(2) || '1.00');
    $('#stat-profile').text(state.profile || 'Normal');
    $('#stat-items').text(economyData.items?.length || 0);
    $('#stat-jobs').text(economyData.jobs?.length || 0);
}

// ══════════════════════════════════════════════════════════════════════════════
// Rendre la liste des items
// ══════════════════════════════════════════════════════════════════════════════

function renderItems() {
    const tbody = $('#itemsTableBody');
    tbody.empty();
    
    economyData.items.forEach(item => {
        const variation = ((item.current_price - item.base_price) / item.base_price * 100).toFixed(2);
        const variationClass = variation >= 0 ? 'positive' : 'negative';
        
        const row = `
            <tr>
                <td>${item.item_name}</td>
                <td>${item.rarity}</td>
                <td>${item.category}</td>
                <td>${parseFloat(item.base_price).toFixed(2)} $</td>
                <td>${parseFloat(item.current_price).toFixed(2)} $</td>
                <td class="${variationClass}">${variation}%</td>
                <td>${item.buy_count || 0}</td>
                <td>${item.sell_count || 0}</td>
                <td>
                    <button class="btn btn-sm btn-primary" onclick="editItemPrice('${item.item_name}', ${item.current_price})">
                        <i class="fas fa-edit"></i>
                    </button>
                </td>
            </tr>
        `;
        
        tbody.append(row);
    });
}

// ══════════════════════════════════════════════════════════════════════════════
// Rendre la liste des jobs
// ══════════════════════════════════════════════════════════════════════════════

function renderJobs() {
    const tbody = $('#jobsTableBody');
    tbody.empty();
    
    economyData.jobs.forEach(job => {
        const baseSalary = parseFloat(job.base_salary) || 0;
        const currentSalary = parseFloat(job.current_salary) || 0;
        const bonus = parseFloat(job.bonus) || 1;
        const variation = baseSalary > 0 ? (((currentSalary - baseSalary) / baseSalary * 100).toFixed(2)) : '0.00';
        const variationClass = variation >= 0 ? 'positive' : 'negative';
        const essential = job.essential ? '<i class="fas fa-check" style="color: #4caf50;"></i>' : '';
        
        const row = `
            <tr>
                <td>${job.job_name}</td>
                <td>${baseSalary.toFixed(2)} $</td>
                <td>${currentSalary.toFixed(2)} $</td>
                <td>x${job.bonus.toFixed(2)}</td>
                <td>${essential}</td>
                <td>${job.active_players || 0}</td>
                <td class="${variationClass}">${variation}%</td>
                <td>
                    <button class="btn btn-sm btn-primary" onclick="editJobSalary('${job.job_name}', ${job.current_salary})">
                        <i class="fas fa-edit"></i>
                    </button>
                </td>
            </tr>
        `;
        
        tbody.append(row);
    });
}

// ══════════════════════════════════════════════════════════════════════════════
// Rendre les taxes
// ══════════════════════════════════════════════════════════════════════════════

function renderTaxes() {
    const taxes = [
        { type: 'achat', rate: 0.05, description: 'Taxe sur les achats' },
        { type: 'vente', rate: 0.03, description: 'Taxe sur les ventes' },
        { type: 'salaire', rate: 0.02, description: 'Taxe sur les salaires' },
        { type: 'transfert', rate: 0.01, description: 'Taxe sur les transferts' },
        { type: 'vehicule', rate: 0.10, description: 'Taxe sur les véhicules' },
        { type: 'immobilier', rate: 0.15, description: 'Taxe immobilière' }
    ];
    
    const tbody = $('#taxesTableBody');
    tbody.empty();
    
    taxes.forEach(tax => {
        const row = `
            <tr>
                <td>${tax.type}</td>
                <td>${(tax.rate * 100).toFixed(1)}%</td>
                <td>${tax.description}</td>
                <td>
                    <button class="btn btn-sm btn-primary" onclick="editTax('${tax.type}', ${tax.rate})">
                        <i class="fas fa-edit"></i>
                    </button>
                </td>
            </tr>
        `;
        
        tbody.append(row);
    });
}

// ══════════════════════════════════════════════════════════════════════════════
// Rendre les logs
// ══════════════════════════════════════════════════════════════════════════════

function renderLogs() {
    const container = $('#logsContainer');
    container.empty();
    
    economyData.logs?.slice(0, 50).forEach(log => {
        const logCard = `
            <div class="log-entry">
                <span class="log-type">${log.log_type}</span>
                <span class="log-item">${log.item_or_job || 'N/A'}</span>
                <span class="log-change">${log.old_value?.toFixed(2) || 'N/A'} → ${log.new_value?.toFixed(2) || 'N/A'}</span>
                <span class="log-date">${log.timestamp}</span>
            </div>
        `;
        
        container.append(logCard);
    });
}

// ══════════════════════════════════════════════════════════════════════════════
// Initialiser les graphiques
// ══════════════════════════════════════════════════════════════════════════════

function initCharts() {
    // TODO: Implémenter les graphiques Chart.js
}

// ══════════════════════════════════════════════════════════════════════════════
// Actions
// ══════════════════════════════════════════════════════════════════════════════

function recalculateEconomy() {
    if (confirm('Voulez-vous recalculer l\'économie maintenant ?')) {
        $.post('https://economy/recalculate', JSON.stringify({}));
    }
}

function resetEconomy() {
    if (confirm('ATTENTION: Cette action réinitialisera toute l\'économie. Êtes-vous sûr ?')) {
        $.post('https://economy/resetEconomy', JSON.stringify({}));
    }
}

function editItemPrice(itemName, currentPrice) {
    const newPrice = prompt(`Nouveau prix pour ${itemName}:`, currentPrice);
    if (newPrice && !isNaN(newPrice)) {
        $.post('https://economy/updateItemPrice', JSON.stringify({
            itemName: itemName,
            newPrice: parseFloat(newPrice)
        }));
    }
}

function editJobSalary(jobName, currentSalary) {
    const newSalary = prompt(`Nouveau salaire pour ${jobName}:`, currentSalary);
    if (newSalary && !isNaN(newSalary)) {
        $.post('https://economy/updateJobSalary', JSON.stringify({
            jobName: jobName,
            newSalary: parseFloat(newSalary)
        }));
    }
}

function editTax(taxType, currentRate) {
    const newRate = prompt(`Nouveau taux pour ${taxType} (0-1):`, currentRate);
    if (newRate && !isNaN(newRate)) {
        $.post('https://economy/updateTax', JSON.stringify({
            taxType: taxType,
            newRate: parseFloat(newRate)
        }));
    }
}

function saveSettings() {
    const multiplier = parseFloat($('#settingMultiplier').val());
    
    $.post('https://economy/setMultiplier', JSON.stringify({
        multiplier: multiplier
    }));
}

// ══════════════════════════════════════════════════════════════════════════════
// Navigation
// ══════════════════════════════════════════════════════════════════════════════

$('.nav-btn').click(function() {
    $('.nav-btn').removeClass('active');
    $(this).addClass('active');
    
    const tab = $(this).data('tab');
    $('.tab-content').removeClass('active');
    $(`#tab-${tab}`).addClass('active');
});

// ══════════════════════════════════════════════════════════════════════════════
// Échap pour fermer
// ══════════════════════════════════════════════════════════════════════════════

$(document).keyup(function(e) {
    if (e.key === 'Escape') {
        closeDashboard();
    }
});
