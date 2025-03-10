import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
    static values = { role: String, id: Number }

    connect() {
        this.#hideOnRoleMismatch()
        this.#hideOnIdMismatch()
    }
    
    #hideOnRoleMismatch() {
        if (this.hasRoleValue && this.roleValue.toLowerCase() !== Current.user?.role?.toLowerCase()) this.#hide();
    }

    #hideOnIdMismatch() {
        if (this.hasIdValue && this.idValue !== Current.user?.id) this.#hide();
    }
    
    #hide() {
        this.element.style.display = 'none';
    }
}
