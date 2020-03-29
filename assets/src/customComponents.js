


class LocalMedia extends HTMLElement {
  constructor() {
    super();

    // Create a shadow root
    //var shadow = this.attachShadow({mode: 'open'});
    //shadow.appendChild(video);

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
