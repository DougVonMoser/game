

export default function () {
    if (sessionStorage.getItem("user_id")) {
        return sessionStorage.getItem("user_id")
    } else {
        let new_user_id = uuidv4();
        sessionStorage.setItem("user_id", new_user_id);
        return new_user_id;
    }
}


// export default function () {
//     if (localStorage.getItem("user_id")) {
//         return localStorage.getItem("user_id")
//     } else {
//         let new_user_id = uuidv4();
//         localStorage.setItem("user_id", new_user_id);
//         return new_user_id;
//     }
// }

function uuidv4() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    var r = Math.random() * 16 | 0, v = c == 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}
