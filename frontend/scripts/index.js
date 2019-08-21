'use strict';
/*
    author: Anjan Roy <anjanroy@yandex.com>
*/

window.addEventListener('DOMContentLoaded', (ev) => {
  // if something goes wrong, we'll let user know that something went
  // unexpectedly bad
  function handleError(error) {
    let errorDiv = document.createElement('div');
    errorDiv.className = 'childDiv';
    let errorArticle = document.createElement('article');
    let errorheading = document.createElement('h1');
    errorheading.innerHTML = 'Error';
    let errorText = document.createElement('p');
    errorText.className = 'playListText';
    errorText.innerHTML = 'Something unexpected happened !!!';
    errorArticle.appendChild(errorheading);
    errorArticle.appendChild(errorText);
    errorDiv.appendChild(errorArticle);
    parentDiv.appendChild(errorDiv);
  }

  // this function handles file uploading & set as one callback function
  function fileUploadHandler(event) {
    let fileUploader = document.getElementById('fileUpload');
    let fileSelected = fileUploader.files[0];
    if (fileSelected.type.startsWith('video', 0)) {
      document.getElementById('uploadPanelText').innerHTML =
          `Upload <small>${fileSelected.name}</small> ?`;
      let button = document.getElementById('uploadConfirmationButton');
      if (button === undefined || button === null) {
        button = document.createElement('button');
        button.id = 'uploadConfirmationButton';
        button.innerHTML = 'Ok';
        button.onmouseenter = (ev) => button.style.backgroundColor = 'green';
        button.onmouseleave = (ev) => button.style.backgroundColor =
            'mediumseagreen';
      }
      button.onclick = (ev) => {
        const abortController =
            new AbortController(); // lets us to abort this upload
        // operation
        let intervalId = displayProgressBar(abortController, fileSelected.name);
        fetch(new URL('upload', window.location.href), {
          method : 'PUT',
          body : fileSelected,
          signal : abortController.signal, // for aborting upload
          headers : new Headers({
            'Content-Disposition' :
                `attachment; filename="${fileSelected.name}"`
          })
        })
            .then((response) => response.json())
            .then((response) => removeProgressBar(intervalId, null),
                  (e) => removeProgressBar(intervalId, e));
      };
      uploadPanel.appendChild(button);
    }
  }

  function displayProgressBar(abortController, filename) {
    let progressBar = document.createElement('progress');
    progressBar.id = 'progressBar';
    progressBar.max = 1;
    progressBar.value = .05;
    progressBar.style.width = '85%';
    let intervalId = setInterval(() => {
      progressBar.value = progressBar.value % 1 + .05;
      progressBar.innerHTML = `${progressBar.value * 100} %`;
    }, 1000);
    document.getElementById('uploadPanelText').innerHTML =
        `Uploading ${filename}`;
    document.getElementById('uploadPanel')
        .replaceChild(progressBar, document.getElementById('fileUpload'));
    let cancelButton = document.createElement('button');
    cancelButton.id = 'cancelUpload';
    cancelButton.innerHTML = 'Cancel';
    cancelButton.style.backgroundColor = 'tomato';
    cancelButton.onmouseenter = (ev) => cancelButton.style.backgroundColor =
        'red';
    cancelButton.onmouseleave = (ev) => cancelButton.style.backgroundColor =
        'tomato';
    cancelButton.onclick = (ev) => { abortController.abort(); };
    document.getElementById('uploadPanel')
        .replaceChild(cancelButton,
                      document.getElementById('uploadConfirmationButton'));
    document.getElementById('heading').style.display = 'none';
    document.getElementById('mainDiv').style.display = 'none';
    document.getElementById('uploadPanel')
        .dispatchEvent(
            new MouseEvent('mouseleave')); // creating this synthetic event
    // so that color gets changed
    return intervalId;
  }

  function removeProgressBar(intervalId, error) {
    clearInterval(intervalId);
    document.getElementById('cancelUpload')
        .parentElement.removeChild(document.getElementById(
            'cancelUpload')); // removing upload cancel button
    document.getElementById('uploadPanelText').innerHTML =
        error === null ? 'Completed !!!'
                       : 'Failed to upload'; // display error, if something went
                                             // wrong during uploading movie
    setTimeout(() => {
      document.getElementById('uploadPanelText').innerHTML =
          'Upload a movie ...';
      let fileUpload = document.createElement('input');
      fileUpload.type = 'file';
      fileUpload.id = 'fileUpload';
      fileUpload.accept = 'video/mp4, video/webm';
      fileUpload.onchange = fileUploadHandler;
      document.getElementById('uploadPanel')
          .replaceChild(fileUpload, document.getElementById('progressBar'));
      document.getElementById('heading').style.display = 'block';
      document.getElementById('mainDiv').style.display = 'block';
      document.getElementById('uploadPanel')
          .blur(); // removing focus from this element
    }, 2000); // setting up a delay of 2 sec. so that user can see final status
              // of trasfer
  }

  function setLightsUpForShow(event) {
    window.navigator.vibrate(
        200); // vibrating device ( supported in mobile platforms ), to denote
    // we're about to start streaming this movie
    let movieName =
        event.target.className === 'playListText'
            ? event.target.innerHTML
            : event.target.className === 'childDiv'
                  ? event.target.childNodes[0].childNodes[0].innerHTML
                  : null; // extracting movie name, which is to be streamed
    if (movieName === null) {
      return;
    }
    // we're asking user whether they wanna stream movie or not
    // on clicking `ok`, it'll start streaming window
    // else it'll simply start downloading movie
    // so if you wanna download movie simply click on `cancel` button, when
    // asked for preference
    if (!confirm("Stream this movie ?")) {
      window.location =
          movieName; // setting this as URL, will let backend know, we're
      // interested in downloading movie
      return;
    }
    while (parentDiv.childElementCount > 0) {
      parentDiv.removeChild(document.getElementById('mainDiv').firstChild);
    }
    document.getElementById('uploadPanel')
        .parentNode.removeChild(document.getElementById('uploadPanel'));
    let childDiv = document.createElement('div');
    childDiv.className = 'childDiv';
    childDiv.style.backgroundColor = '#363636';
    childDiv.style.width = '95%';
    let videoText = document.createElement('p');
    videoText.style.color = 'snow';
    videoText.style.marginLeft = '1vmax';
    videoText.style.marginBottom = '0';
    videoText.style.paddingBottom = '0';
    videoText.style.fontFamily = "Georgia, 'Times New Roman', Times, serif";
    videoText.style.fontWeight = 'bold';
    videoText.style.fontSize = '2vmax';
    videoText.innerHTML = movieName.split('.').slice(0, -1).join(' ');
    let video = document.createElement('video');
    video.id = "video";
    video.onclick = (ev) => {
      let videoElement = document.getElementById("video");
      if (videoElement.paused) {
        videoElement.play();
      } else {
        videoElement.pause();
      }
    };
    video.style.width = "100%";
    video.style.outline = "none";
    video.width = window.innerWidth - 20;
    video.height = (video.width * 9) / 16;
    video.controls = true;
    video.preload = "metadata";
    let source = document.createElement("source");
    source.src = movieName;
    source.type = `video/${
        movieName.split('.').slice(-1)[0]}`; // setting video to streamed's type
    video.innerHTML = "Something went wrong !!!"; // it's a fallback note
    video.appendChild(source);
    childDiv.appendChild(videoText);
    childDiv.appendChild(video);
    parentDiv.appendChild(childDiv);
  }

  let parentDiv = document.getElementById('mainDiv');

  let uploadPanel = document.getElementById('uploadPanel');
  uploadPanel.onmouseenter = (ev) => {
    uploadPanel.style.backgroundColor = 'yellow';
    document.getElementById('uploadPanelText').style.color = 'black';
  };
  uploadPanel.onmouseleave = (ev) => {
    uploadPanel.style.backgroundColor = '#262626';
    document.getElementById('uploadPanelText').style.color = 'yellow';
  };
  let fileUploader = document.getElementById('fileUpload');
  fileUploader.onchange = fileUploadHandler;

  // fetches list of movies, which can be streamed from backend using HTML5
  // Fetch API and generates UI dynamically
  fetch(new URL('movies', window.location.href)).then((resp) => {
    resp.json().then((data) => {
      data.path.sort().forEach((elem) => {
        let movieDiv = document.createElement('div');
        movieDiv.className = 'childDiv';
        movieDiv.onmouseenter = (ev) => {
          ev.target.style.backgroundColor = 'aqua';
          let text = ev.target.childNodes[0].childNodes[0];
          text.style.color = 'black';
        };
        movieDiv.onmouseleave = (ev) => {
          ev.target.style.backgroundColor = 'cadetblue';
          let text = ev.target.childNodes[0].childNodes[0];
          text.style.color = 'snow';
        };
        movieDiv.onclick =
            setLightsUpForShow; // clicking on a movieName will ask user for
        // his/ her preference,
        // would he/ she like to stream movie or not
        let movieArticle = document.createElement('article');
        let movieName = document.createElement('p');
        movieName.className = 'playListText';
        movieName.innerHTML = elem;
        movieArticle.appendChild(movieName);
        movieDiv.appendChild(movieArticle);
        parentDiv.appendChild(movieDiv);
      });
    }, handleError);
  }, handleError);
});
