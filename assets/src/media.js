export default bindMedia;

var localStream = null;
var remoteStream = null;
var peerConnection = null;

//var event = new Event('test-event');


async function bindMedia(){
        let stream = await navigator.mediaDevices.getUserMedia( {video: true, audio: true});
        localStream = stream;

        //could be used for player hash specific events
        var event = new CustomEvent("test-event", {
          detail: stream
        });

        window.dispatchEvent(event);


        remoteStream = new MediaStream();
        //document.querySelector('#remoteVideo').srcObject = remoteStream;
        peerConnection = new RTCPeerConnection(null);

        localStream.getTracks().forEach(track => {
            console.log("adding track", track)
            peerConnection.addTrack(track, localStream);
        });

        peerConnection.addEventListener('icecandidate', event => {
            
            if (!event.candidate) {
              console.log('Got final candidate!');
              return;
            }
            console.log('Got candidate: ', event.candidate);
            //callerCandidatesCollection.add(event.candidate.toJSON());
        });
        const offer = await peerConnection.createOffer()
        await peerConnection.setLocalDescription(offer);
}
