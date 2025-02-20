# Log rendering 🎨 🖌

Log rendering plays the crucial role in today's CI/CD systems. Whether it is a failed test you need to debug or you want to follow output while job is still running, you want it to be rendered nicely and fast!
<br><br>
<p align="center">
  <img src="https://user-images.githubusercontent.com/9396752/117674176-bd657900-b1ab-11eb-939c-733f8992b3eb.gif" alt="animated" />
</p>
<br><br>

## Code

Semaphore renders log output in your browser instead of serving it from the backend. Some other services are using the second approach and render full log HTML in the backend. See BuildKite's [terminal-to-html](https://github.com/buildkite/terminal-to-html) library as an example. Running the log renderer on the client side provides us with more power to serve thousands of rendering requests in parallel without affecting performance.

Semaphore log renderer is implemented in Javascript. Code is served and placed in our main UI app, in *`front/assets/js/job_logs/`* subdirectory.

The code is organized the following way:

1. Event Fetcher takes raw JSON events from the backend
2. Renderer takes fetched events
3. Renderer builds Job Output model based on raw events
4. Renderer renders HTML using templates
5. Renderer appends new HTML to the browser DOM

![image](https://user-images.githubusercontent.com/9396752/117786205-8e9be100-b245-11eb-9498-704d4d0e9f2f.png)

### Events

There are five types of log events that Renderer needs to handle:

1. Job Started
2. Command Started
3. Command Output
4. Command Finished
5. Job Finished

### Models

![image](https://user-images.githubusercontent.com/9396752/117681542-7d55c480-b1b2-11eb-899e-57008c32be9f.png)

### Templates

Each model class has dedicated template class for generating its HTML.

### Renderer

![image](https://user-images.githubusercontent.com/9396752/117683883-c73faa00-b1b4-11eb-9201-f0a6c7b55b9a.png)
