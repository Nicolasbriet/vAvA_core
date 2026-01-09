/* ============================================
   vAvA TESTBENCH - Application Logic
   ============================================ */

console.log('[TESTBENCH] app.js loading...');

// === GLOBALS ===
const AppState = {
    modules: [],
    tests: [],
    logs: [],
    scenarios: [],
    runningTests: new Set(),
    results: {
        passed: 0,
        failed: 0,
        warnings: 0
    },
    selectedScenario: null,
    startTime: null
};

// === INITIALIZATION ===
window.addEventListener('DOMContentLoaded', () => {
    initApp();
    setupEventListeners();
    setupNUIListeners();
});

function initApp() {
    console.log('🚀 vAvA Testbench initialized');
    showNotification('Testbench Ready', 'Système de test initialisé', 'success');
    
    // Demander les données initiales au serveur
    // Les données arriveront via l'event 'updateModules'
    fetchNUI('testbench:getInitialData', {});
}

// === EVENT LISTENERS ===
function setupEventListeners() {
    // Header buttons
    document.getElementById('btn-scan')?.addEventListener('click', scanModules);
    document.getElementById('btn-run-all')?.addEventListener('click', runAllTests);
    document.getElementById('btn-stop')?.addEventListener('click', stopTests);
    document.getElementById('btn-export')?.addEventListener('click', exportResults);
    document.getElementById('btn-close')?.addEventListener('click', closeTestbench);
    
    // Tab navigation
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.addEventListener('click', (e) => switchTab(e.target.closest('.tab-btn').dataset.tab));
    });
    
    // Search & filters
    document.getElementById('search-modules')?.addEventListener('input', filterModules);
    document.getElementById('filter-test-type')?.addEventListener('change', filterTests);
    document.getElementById('filter-test-status')?.addEventListener('change', filterTests);
    document.getElementById('filter-log-level')?.addEventListener('change', filterLogs);
    
    // Logs
    document.getElementById('btn-clear-logs')?.addEventListener('click', clearLogs);
    document.getElementById('btn-clear-console')?.addEventListener('click', clearConsole);
    
    // Console toggle
    document.getElementById('console-toggle')?.addEventListener('click', toggleConsole);
    
    // Scenarios
    document.getElementById('btn-run-scenario')?.addEventListener('click', runSelectedScenario);
    
    // ESC key to close
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') closeTestbench();
    });
}

function setupNUIListeners() {
    // Écouter les messages NUI du client Lua
    window.addEventListener('message', (event) => {
        const data = event.data;
        
        switch(data.action) {
            case 'show':
                showTestbench();
                break;
            case 'hide':
                hideTestbench();
                break;
            case 'updateModules':
                AppState.modules = data.modules;
                renderModules();
                break;
            case 'testStarted':
                handleTestStarted(data.test);
                break;
            case 'testCompleted':
                handleTestCompleted(data.result);
                break;
            case 'addLog':
                addLog(data.log);
                break;
            case 'updateStats':
                updateStats(data.stats);
                break;
        }
    });
}

// === UI FUNCTIONS ===
function showTestbench() {
    const container = document.getElementById('testbench-container');
    container.classList.remove('hidden');
    document.body.style.overflow = 'hidden';
}

function hideTestbench() {
    const container = document.getElementById('testbench-container');
    container.classList.add('hidden');
    document.body.style.overflow = 'auto';
}

function closeTestbench() {
    hideTestbench();
    fetchNUI('testbench:close', {});
}

function switchTab(tabName) {
    // Update buttons
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.classList.toggle('active', btn.dataset.tab === tabName);
    });
    
    // Update content
    document.querySelectorAll('.tab-content').forEach(content => {
        content.classList.toggle('active', content.id === `tab-${tabName}`);
    });
}

// === MODULES ===
function scanModules() {
    showNotification('Scanning...', 'Détection des modules en cours', 'info');
    addConsoleLog('🔍 Scan des modules démarré...');
    
    fetchNUI('testbench:scanModules', {}).then(data => {
        if (data && data.modules) {
            AppState.modules = data.modules;
            renderModules();
            updateStats({ modules: data.modules.length });
            showNotification('Scan Complete', `${data.modules.length} module(s) détecté(s)`, 'success');
            addConsoleLog(`✅ ${data.modules.length} module(s) détecté(s)`);
        }
    });
}

function renderModules() {
    const container = document.getElementById('modules-grid');
    if (!container) return;
    
    container.innerHTML = '';
    
    if (AppState.modules.length === 0) {
        container.innerHTML = `
            <div class="empty-state" style="grid-column: 1/-1;">
                <svg viewBox="0 0 24 24" class="icon-large">
                    <rect x="3" y="3" width="18" height="18" stroke="currentColor" fill="none"/>
                    <path d="M12 8v8M8 12h8" stroke="currentColor"/>
                </svg>
                <p>Aucun module détecté. Cliquez sur "SCAN" pour détecter les modules.</p>
            </div>
        `;
        return;
    }
    
    AppState.modules.forEach(module => {
        const card = createModuleCard(module);
        container.appendChild(card);
    });
}

function createModuleCard(module) {
    const div = document.createElement('div');
    div.className = 'module-card';
    div.onclick = () => viewModuleDetails(module);
    
    const isTested = module.testsCount > 0;
    const passRate = module.testsCount > 0 ? Math.round((module.testsPassed / module.testsCount) * 100) : 0;
    
    div.innerHTML = `
        <div class="module-header">
            <span class="module-name">${module.name}</span>
            <span class="module-badge ${isTested ? 'tested' : 'untested'}">
                ${isTested ? 'TESTED' : 'UNTESTED'}
            </span>
        </div>
        <div class="module-stats">
            <div class="module-stat">
                <span>📋</span>
                <span>${module.testsCount || 0} tests</span>
            </div>
            <div class="module-stat">
                <span>✅</span>
                <span>${passRate}%</span>
            </div>
            <div class="module-stat">
                <span>⏱</span>
                <span>${module.avgTime || 0}ms</span>
            </div>
        </div>
    `;
    
    return div;
}

function viewModuleDetails(module) {
    showNotification('Module Details', `Détails de ${module.name}`, 'info');
    addConsoleLog(`📦 Visualisation du module: ${module.name}`);
    
    fetchNUI('testbench:getModuleDetails', { moduleName: module.name }).then(data => {
        if (data && data.tests) {
            AppState.tests = data.tests;
            renderTests();
            switchTab('tests');
        }
    });
}

function filterModules() {
    const searchTerm = document.getElementById('search-modules')?.value.toLowerCase() || '';
    const showTested = document.getElementById('filter-tested')?.checked ?? true;
    const showUntested = document.getElementById('filter-untested')?.checked ?? true;
    
    document.querySelectorAll('.module-card').forEach(card => {
        const moduleName = card.querySelector('.module-name').textContent.toLowerCase();
        const isTested = card.querySelector('.module-badge').classList.contains('tested');
        
        const matchesSearch = moduleName.includes(searchTerm);
        const matchesFilter = (isTested && showTested) || (!isTested && showUntested);
        
        card.style.display = (matchesSearch && matchesFilter) ? 'block' : 'none';
    });
}

// === TESTS ===
function runAllTests() {
    const btn = document.getElementById('btn-run-all');
    const stopBtn = document.getElementById('btn-stop');
    
    btn.disabled = true;
    stopBtn.disabled = false;
    
    AppState.startTime = Date.now();
    AppState.results = { passed: 0, failed: 0, warnings: 0 };
    
    showNotification('Tests Started', 'Exécution de tous les tests...', 'info');
    addConsoleLog('▶️ Démarrage de tous les tests...');
    
    fetchNUI('testbench:runAllTests', {}).then(data => {
        btn.disabled = false;
        stopBtn.disabled = true;
        
        if (data) {
            showNotification('Tests Complete', 'Tous les tests sont terminés', 'success');
            addConsoleLog(`✅ Tests terminés: ${data.passed} réussis, ${data.failed} échoués`);
        }
    });
}

function stopTests() {
    fetchNUI('testbench:stopTests', {});
    
    document.getElementById('btn-run-all').disabled = false;
    document.getElementById('btn-stop').disabled = true;
    
    showNotification('Tests Stopped', 'Tests arrêtés', 'warning');
    addConsoleLog('⏹️ Tests arrêtés par l\'utilisateur');
}

function handleTestStarted(test) {
    AppState.runningTests.add(test.name);
    
    const container = document.getElementById('running-tests-list');
    if (!container) return;
    
    // Remove empty state
    const emptyState = container.querySelector('.empty-state');
    if (emptyState) emptyState.remove();
    
    // Add running test item
    const div = document.createElement('div');
    div.className = 'running-test-item';
    div.id = `running-${test.name}`;
    div.innerHTML = `
        <span class="running-test-name">${test.name}</span>
        <div class="running-test-spinner"></div>
    `;
    container.appendChild(div);
    
    // Update running count
    document.getElementById('running-count').textContent = AppState.runningTests.size;
    
    addConsoleLog(`🧪 Test démarré: ${test.name}`);
}

function handleTestCompleted(result) {
    AppState.runningTests.delete(result.name);
    
    // Remove from running list
    const runningItem = document.getElementById(`running-${result.name}`);
    if (runningItem) runningItem.remove();
    
    // Update running count
    const runningCount = document.getElementById('running-count');
    if (runningCount) runningCount.textContent = AppState.runningTests.size;
    
    // Show empty state if no tests running
    const runningList = document.getElementById('running-tests-list');
    if (runningList && AppState.runningTests.size === 0) {
        runningList.innerHTML = `
            <div class="empty-state">
                <svg viewBox="0 0 24 24" class="icon-large">
                    <circle cx="12" cy="12" r="10" stroke="currentColor" fill="none"/>
                    <path d="M12 6v6l4 2" stroke="currentColor" fill="none"/>
                </svg>
                <p>Aucun test en cours</p>
            </div>
        `;
    }
    
    // Update results
    if (result.status === 'passed') {
        AppState.results.passed++;
    } else if (result.status === 'failed') {
        AppState.results.failed++;
    } else if (result.status === 'warning') {
        AppState.results.warnings++;
    }
    
    updateStats(AppState.results);
    
    // Add to recent results
    addRecentResult(result);
    
    // Log
    const emoji = result.status === 'passed' ? '✅' : result.status === 'failed' ? '❌' : '⚠️';
    addConsoleLog(`${emoji} ${result.name}: ${result.status.toUpperCase()} (${result.duration}ms)`);
    
    // Show notification for failures
    if (result.status === 'failed') {
        showNotification('Test Failed', result.name, 'error');
    }
}

function addRecentResult(result) {
    const container = document.getElementById('recent-results-list');
    if (!container) return;
    
    const div = document.createElement('div');
    div.className = `result-item ${result.status}`;
    div.innerHTML = `
        <span class="result-name">${result.name}</span>
        <span class="result-time">${result.duration}ms</span>
    `;
    
    container.insertBefore(div, container.firstChild);
    
    // Keep only last 10 results
    while (container.children.length > 10) {
        container.removeChild(container.lastChild);
    }
}

function renderTests() {
    const container = document.getElementById('tests-list');
    if (!container) return;
    
    container.innerHTML = '';
    
    if (AppState.tests.length === 0) {
        container.innerHTML = `
            <div class="empty-state">
                <p>Aucun test disponible</p>
            </div>
        `;
        return;
    }
    
    AppState.tests.forEach(test => {
        const div = createTestItem(test);
        container.appendChild(div);
    });
}

function createTestItem(test) {
    const div = document.createElement('div');
    div.className = `test-item ${test.status || 'pending'}`;
    
    div.innerHTML = `
        <div class="test-header">
            <span class="test-name">${test.name}</span>
            <span class="test-type-badge ${test.type}">${test.type.toUpperCase()}</span>
        </div>
        <div class="test-details">
            <span>${test.description || 'No description'}</span>
            ${test.duration ? `<span> • ${test.duration}ms</span>` : ''}
        </div>
    `;
    
    div.onclick = () => runSingleTest(test);
    
    return div;
}

function runSingleTest(test) {
    showNotification('Running Test', test.name, 'info');
    fetchNUI('testbench:runTest', { testName: test.name });
}

function filterTests() {
    const typeFilter = document.getElementById('filter-test-type')?.value || 'all';
    const statusFilter = document.getElementById('filter-test-status')?.value || 'all';
    
    document.querySelectorAll('.test-item').forEach(item => {
        const testType = item.querySelector('.test-type-badge')?.textContent.toLowerCase() || '';
        const testStatus = item.classList.contains('passed') ? 'passed' :
                          item.classList.contains('failed') ? 'failed' : 'pending';
        
        const matchesType = typeFilter === 'all' || testType === typeFilter;
        const matchesStatus = statusFilter === 'all' || testStatus === statusFilter;
        
        item.style.display = (matchesType && matchesStatus) ? 'block' : 'none';
    });
}

// === LOGS ===
function addLog(log) {
    AppState.logs.push(log);
    
    const container = document.getElementById('logs-container');
    if (!container) return;
    
    const div = document.createElement('div');
    div.className = `log-entry ${log.level}`;
    div.innerHTML = `
        <span class="log-time">[${formatTime(log.timestamp)}]</span>
        <span class="log-level">${log.level}</span>
        <span class="log-message">${log.message}</span>
    `;
    
    container.appendChild(div);
    container.scrollTop = container.scrollHeight;
    
    // Keep only last 100 logs
    while (container.children.length > 100) {
        container.removeChild(container.firstChild);
    }
}

function addConsoleLog(message) {
    const container = document.getElementById('console-logs');
    if (!container) return;
    
    const div = document.createElement('div');
    div.textContent = `[${formatTime(Date.now())}] ${message}`;
    div.style.color = 'var(--text-gray)';
    
    container.appendChild(div);
    container.scrollTop = container.scrollHeight;
}

function clearLogs() {
    const container = document.getElementById('logs-container');
    if (container) container.innerHTML = '';
    AppState.logs = [];
    addConsoleLog('🗑️ Logs effacés');
}

function clearConsole() {
    const container = document.getElementById('console-logs');
    if (container) container.innerHTML = '';
}

function filterLogs() {
    const levelFilter = document.getElementById('filter-log-level')?.value || 'all';
    
    document.querySelectorAll('.log-entry').forEach(entry => {
        const logLevel = entry.classList[1]; // Second class is the level
        const matches = levelFilter === 'all' || logLevel === levelFilter;
        entry.style.display = matches ? 'block' : 'none';
    });
}

function toggleConsole() {
    const terminal = document.getElementById('console-terminal');
    terminal.classList.toggle('collapsed');
    
    const title = document.getElementById('console-toggle').querySelector('.console-title');
    title.textContent = terminal.classList.contains('collapsed') ? '▲ CONSOLE' : '▼ CONSOLE';
}

// === SCENARIOS ===
function renderScenarios() {
    const container = document.getElementById('scenarios-list');
    if (!container) return;
    
    container.innerHTML = '';
    
    if (AppState.scenarios.length === 0) {
        container.innerHTML = `
            <div class="empty-state">
                <p>Aucun scénario disponible</p>
            </div>
        `;
        return;
    }
    
    AppState.scenarios.forEach(scenario => {
        const div = createScenarioCard(scenario);
        container.appendChild(div);
    });
}

function createScenarioCard(scenario) {
    const div = document.createElement('div');
    div.className = 'scenario-card';
    div.onclick = () => selectScenario(scenario);
    
    div.innerHTML = `
        <div class="scenario-header">
            <span class="scenario-name">${scenario.name}</span>
            ${scenario.critical ? '<span class="module-badge tested">CRITICAL</span>' : ''}
        </div>
        <div class="scenario-steps">
            ${scenario.steps.map(step => `<span class="scenario-step">${step}</span>`).join('')}
        </div>
    `;
    
    return div;
}

function selectScenario(scenario) {
    AppState.selectedScenario = scenario;
    
    document.querySelectorAll('.scenario-card').forEach(card => {
        card.classList.remove('selected');
    });
    
    event.target.closest('.scenario-card').classList.add('selected');
    
    showNotification('Scenario Selected', scenario.name, 'info');
}

function runSelectedScenario() {
    if (!AppState.selectedScenario) {
        showNotification('No Scenario', 'Veuillez sélectionner un scénario', 'warning');
        return;
    }
    
    showNotification('Running Scenario', AppState.selectedScenario.name, 'info');
    addConsoleLog(`🎬 Exécution du scénario: ${AppState.selectedScenario.name}`);
    
    fetchNUI('testbench:runScenario', { scenario: AppState.selectedScenario.name });
}

// === STATS ===
function updateStats(stats) {
    if (stats.passed !== undefined) {
        document.getElementById('stat-passed').textContent = stats.passed;
    }
    if (stats.failed !== undefined) {
        document.getElementById('stat-failed').textContent = stats.failed;
    }
    if (stats.warnings !== undefined) {
        document.getElementById('stat-warnings').textContent = stats.warnings;
    }
    if (stats.modules !== undefined) {
        document.getElementById('stat-modules').textContent = stats.modules;
    }
    
    // Update time
    if (AppState.startTime) {
        const elapsed = Date.now() - AppState.startTime;
        document.getElementById('stat-time').textContent = `${elapsed}ms`;
    }
    
    // Update progress
    const total = (stats.passed || 0) + (stats.failed || 0);
    const testsCount = AppState.tests.length || 1;
    const progress = Math.min((total / testsCount) * 100, 100);
    document.getElementById('progress-fill').style.width = `${progress}%`;
}

// === EXPORT ===
function exportResults() {
    const data = {
        timestamp: new Date().toISOString(),
        results: AppState.results,
        modules: AppState.modules,
        tests: AppState.tests,
        logs: AppState.logs
    };
    
    fetchNUI('testbench:export', { data: JSON.stringify(data) }).then(() => {
        showNotification('Export Complete', 'Résultats exportés', 'success');
        addConsoleLog('💾 Résultats exportés avec succès');
    });
}

// === NOTIFICATIONS ===
function showNotification(title, message, type = 'info') {
    const toast = document.getElementById('notification-toast');
    const icon = toast.querySelector('.toast-icon');
    const titleEl = toast.querySelector('.toast-title');
    const messageEl = toast.querySelector('.toast-message');
    
    const icons = {
        success: '✅',
        error: '❌',
        warning: '⚠️',
        info: 'ℹ️'
    };
    
    icon.textContent = icons[type] || icons.info;
    titleEl.textContent = title;
    messageEl.textContent = message;
    
    toast.classList.remove('hidden');
    
    setTimeout(() => {
        toast.classList.add('hidden');
    }, 4000);
}

// === UTILITIES ===
function formatTime(timestamp) {
    const date = new Date(timestamp);
    return `${padZero(date.getHours())}:${padZero(date.getMinutes())}:${padZero(date.getSeconds())}`;
}

function padZero(num) {
    return num.toString().padStart(2, '0');
}

async function fetchNUI(eventName, data = {}) {
    try {
        const response = await fetch(`https://${GetParentResourceName()}/${eventName}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        });
        
        // Vérifier si la réponse est OK
        if (!response.ok) {
            console.error(`HTTP error from ${eventName}: ${response.status}`);
            return { success: false, error: `HTTP ${response.status}` };
        }
        
        const text = await response.text();
        
        // Vérifier si la réponse est vide
        if (!text || text.trim() === '') {
            console.warn(`Empty response from ${eventName}`);
            return { success: true };
        }
        
        // Tenter de parser le JSON
        try {
            return JSON.parse(text);
        } catch (parseError) {
            console.warn(`Non-JSON response from ${eventName}: "${text}"`);
            return { success: true, raw: text };
        }
    } catch (error) {
        console.error(`NUI Fetch Error (${eventName}):`, error);
        return { success: false, error: error.message };
    }
}

function GetParentResourceName() {
    // In-game: get resource name from cfx-nui URL
    const url = window.location.href;
    console.log('[TESTBENCH] Current URL:', url);
    
    // FiveM uses format: https://cfx-nui-resource_name/...
    const match = url.match(/https?:\/\/cfx-nui-([^\/]+)/);
    if (match) {
        console.log('[TESTBENCH] Resource name:', match[1]);
        return match[1];
    }
    
    // Fallback for dev/testing
    console.warn('[TESTBENCH] Could not detect resource name, using fallback');
    return 'vAvA_testbench';
}

// === CHART (Optional - can be enhanced with Chart.js) ===
// For now, placeholder
console.log('📊 Chart placeholder - Can integrate Chart.js for graphs');
