$(document).ready(function() {
    let currentMenu = null;

    // Écouter les messages du jeu
    window.addEventListener('message', function(event) {
        const data = event.data;
        
        switch(data.action) {
            case 'openMenu':
                openMenu(data.id, data.title, data.options);
                break;
            case 'openJobInfo':
                openJobInfo(data.jobData);
                break;
            case 'close':
                closeAllMenus();
                break;
        }
    });

    // Fermer avec ESC
    $(document).keyup(function(e) {
        if (e.key === "Escape") {
            closeAllMenus();
        }
    });

    /**
     * Ouvre un menu
     */
    function openMenu(id, title, options) {
        currentMenu = id;
        
        $('#menu-title').text(title);
        $('#menu-options').empty();
        
        if (!options || options.length === 0) {
            $('#menu-options').html(`
                <div class="empty-state">
                    <i class="fas fa-briefcase"></i>
                    <p>Aucune option disponible</p>
                </div>
            `);
        } else {
            options.forEach((option, index) => {
                const optionEl = createOptionElement(option, index);
                $('#menu-options').append(optionEl);
            });
        }
        
        $('#jobs-menu').removeClass('hidden');
        setFocus(true);
    }

    /**
     * Ouvre la carte d'informations job
     */
    function openJobInfo(jobData) {
        if (!jobData) return;
        
        // Mettre à jour l'icône selon le job
        const jobIcons = {
            'police': 'fas fa-shield-alt',
            'ambulance': 'fas fa-heartbeat',
            'mechanic': 'fas fa-wrench',
            'taxi': 'fas fa-taxi',
            'unemployed': 'fas fa-user-times'
        };
        
        const icon = jobIcons[jobData.name] || 'fas fa-briefcase';
        $('#job-card-icon').attr('class', icon);
        
        // Informations principales
        $('#job-card-title').text(jobData.label || 'Job Inconnu');
        $('#job-card-subtitle').text(jobData.gradeLabel || 'Grade Inconnu');
        
        // Statistiques
        $('#job-salary').text('$' + (jobData.salary || 0).toLocaleString());
        $('#job-duty').text(jobData.onDuty ? 'En Service' : 'Hors Service');
        $('#job-colleagues').text(jobData.colleagues || '0');
        
        // Permissions
        const permsList = $('#job-perms-list');
        permsList.empty();
        
        if (jobData.permissions && jobData.permissions.length > 0) {
            jobData.permissions.forEach(perm => {
                permsList.append(`<span class="perm-badge">${perm}</span>`);
            });
        } else {
            permsList.append('<span class="perm-badge">Aucune</span>');
        }
        
        $('#job-info-card').removeClass('hidden');
        setFocus(true);
    }

    /**
     * Ferme tous les menus
     */
    function closeAllMenus() {
        $('#jobs-menu').addClass('hidden');
        $('#job-info-card').addClass('hidden');
        currentMenu = null;
        setFocus(false);
        
        // Notifier le client Lua
        $.post(`https://${GetParentResourceName()}/close`);
    }

    /**
     * Ferme le menu principal
     */
    window.closeMenu = function() {
        $('#jobs-menu').addClass('hidden');
        currentMenu = null;
        setFocus(false);
        
        $.post(`https://${GetParentResourceName()}/close`);
    }

    /**
     * Ferme la carte job
     */
    window.closeJobCard = function() {
        $('#job-info-card').addClass('hidden');
        setFocus(false);
        
        $.post(`https://${GetParentResourceName()}/close`);
    }

    /**
     * Gère le focus
     */
    function setFocus(focus) {
        $.post(`https://${GetParentResourceName()}/setFocus`, JSON.stringify({
            focus: focus,
            cursor: focus
        }));
    }

    /**
     * Crée un élément d'option pour le menu
     */
    function createOptionElement(option, index) {
        const iconClass = option.icon || 'fas fa-cog';
        const description = option.description || '';
        
        const element = $(`
            <div class="menu-option" data-action="${option.action}" data-index="${index}">
                <div class="option-icon">
                    <i class="${iconClass}"></i>
                </div>
                <div class="option-content">
                    <div class="option-title">${option.label}</div>
                    ${description ? `<div class="option-description">${description}</div>` : ''}
                </div>
                <div class="option-arrow">
                    <i class="fas fa-chevron-right"></i>
                </div>
            </div>
        `);
        
        // Ajouter le gestionnaire de clic
        element.click(function() {
            const action = $(this).data('action');
            const idx = $(this).data('index');
            
            if (action && action !== '') {
                $.post(`https://${GetParentResourceName()}/${action}`, JSON.stringify({
                    option: option,
                    index: idx
                }));
                
                // Fermer le menu après sélection si spécifié
                if (option.closeOnSelect !== false) {
                    closeMenu();
                }
            }
        });
        
        return element;
    }

    /**
     * Utilitaire pour obtenir le nom de la ressource parent
     */
    function GetParentResourceName() {
        return window.location.hostname;
    }
});

    /**
     * Crée un élément d'option
     */
    function createOptionElement(option, index) {
        const icon = option.icon || 'fas fa-circle';
        const description = option.description || '';
        const hasArrow = option.menu || option.onSelect;
        
        const optionEl = $(`
            <div class="menu-option" data-index="${index}">
                <div class="option-icon">
                    <i class="${icon}"></i>
                </div>
                <div class="option-content">
                    <div class="option-title">${option.title}</div>
                    ${description ? `<div class="option-description">${description}</div>` : ''}
                </div>
                ${hasArrow ? '<i class="fas fa-chevron-right option-arrow"></i>' : ''}
            </div>
        `);
        
        // Gérer le clic
        optionEl.on('click', function() {
            if (option.onSelect) {
                // Exécuter le callback
                executeCallback(option.onSelect);
            } else if (option.menu) {
                // Ouvrir un sous-menu
                openSubMenu(option.menu);
            }
        });
        
        return optionEl;
    }

    /**
     * Exécute un callback
     */
    function executeCallback(callback) {
        $.post(`https://${GetParentResourceName()}/selectOption`, JSON.stringify({
            callback: callback.toString()
        }));
        
        closeMenu();
    }

    /**
     * Ouvre un sous-menu
     */
    function openSubMenu(menuId) {
        $.post(`https://${GetParentResourceName()}/openSubMenu`, JSON.stringify({
            menu: menuId
        }));
    }

    /**
     * Ferme le menu
     */
    window.closeMenu = function() {
        $('#jobs-menu').addClass('hidden');
        $.post(`https://${GetParentResourceName()}/closeMenu`, JSON.stringify({}));
    }

    /**
     * Récupère le nom de la ressource parente
     */
    function GetParentResourceName() {
        let name = 'jobs'; // Nom par défaut
        
        // Essayer de récupérer depuis l'URL
        if (window.location.href.includes('nui://')) {
            const parts = window.location.href.split('/');
            if (parts.length >= 4) {
                name = parts[3];
            }
        }
        
        return name;
    }
});
