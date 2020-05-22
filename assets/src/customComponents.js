


class LocalMedia extends HTMLElement {

  connectedCallback() {

    // could be used for player id specific events
    let testInitDataFromElm = this.dataset.tester
    window.addEventListener('test-event',  (e) =>  {


        let video = document.createElement('video');
        video.setAttribute("playsinline", true);
        video.setAttribute("autoplay", true);
        video.setAttribute("muted", true);
        video.classList.add("selectable");
        this.appendChild(video);

        video.srcObject = e.detail;
    }, false);
   }
}

// Define the new element
customElements.define('local-media', LocalMedia);



export default {};
