export default function toggleSpinner() {
  const spinner = document.querySelector(".spinner")
  
  if (!spinner) {
    return
  }
  
  if(spinner.style.display == "none"){
    spinner.style.display = "block"
  }else{
    spinner.style.display = "none"
  }
}