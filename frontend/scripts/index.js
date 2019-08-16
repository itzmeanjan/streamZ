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
