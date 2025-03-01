import { Controller } from "@hotwired/stimulus"
import { post } from "@rails/request.js"

export default class extends Controller {
    static values = { url: String, roomId: Number }
    
    connect() {
        this.updateLastVisitedRoom();
    }

    async updateLastVisitedRoom() {
        await post(this.urlValue);
    }
} 