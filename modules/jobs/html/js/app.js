$(document).ready(function() {
    let currentMenu = null;

    // Écouter les messages du jeu
    window.addEventListener('message', function(event) {
        const data = event.data;
        
        switch(data.action) {
            case 'openMenu':
                openMenu(data.id, data.title, data.options);
                break;
            case 'close':
                closeMenu();
                break;
        }
    });

    // Fermer avec ESC
    $(document).keyup(function(e) {
        if (e.key === "Escape") {
            closeMenu();
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
                    <i class="fas fa-inbox"></i>
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
    }

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
