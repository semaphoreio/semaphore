// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import { Notice } from "js/notice";

interface SkipOnboardingOptions {
  skipOnboardingUrl: string;
  csrfToken: string;
  projectUrl: string;
}

export const handleSkipOnboarding = async ({ 
  skipOnboardingUrl, 
  csrfToken, 
  projectUrl 
}: SkipOnboardingOptions): Promise<void> => {
  try {
    const response = await fetch(skipOnboardingUrl, {
      method: `POST`,
      headers: {
        'Content-Type': `application/json`,
        'X-CSRF-Token': csrfToken,
      },
      credentials: `same-origin`
    });

    const data = await response.json();

    if (data.redirect_to) {
      window.location.href = data.redirect_to;
    } else {
      Notice.error(`Error during skip onboarding: Invalid response from server`);
    }
  } catch (error: unknown) {
    const errorMessage = error instanceof Error
      ? error.message
      : `Unknown error occurred`;

    Notice.error(`Error during skip onboarding: ` + errorMessage);
    // Fallback to project URL in case of error
    window.location.href = projectUrl;
  }
};