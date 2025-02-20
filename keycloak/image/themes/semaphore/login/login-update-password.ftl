<#import "template.ftl" as layout>
<#import "password-commons.ftl" as passwordCommons>
<@layout.registrationLayout displayMessage=!messagesPerField.existsError('password','password-confirm'); section>
    <#if section = "form">
        <div class="tc mt6 mb4">
            <img decoding="async" width="164" height="23" src="https://semaphoreci.com/wp-content/uploads/2024/04/semaphore-logo.svg" alt="" class="wp-image-23606">
        </div>
        <div class="mw6 center br4 pa4" style="background:linear-gradient(43deg,rgb(199,218,255) 0%,rgb(194,240,215) 100%);">
            <div class="bg-white ba pa3 br4" style="border-color: #ccc;">
                <div class="gray tc f4 mt2">

                </div>
                <form id="kc-passwd-update-form" class="a3 ${properties.kcFormClass!}" action="${url.loginAction}" method="post">
                <div class="mb3">
                    <label for="password-new" class="f4 db b mb2">
                        ${msg("passwordNew")}
                    </label>
                    <div>
                        <input class="form-control w-100" type="password" id="password-new" name="password-new" autofocus autocomplete="new-password"
                                aria-invalid="<#if messagesPerField.existsError('password','password-confirm')>true</#if>"
                        />
                    </div>

                    <#if messagesPerField.existsError('password')>
                        <span id="input-error-password" class="red mb3" aria-live="polite">
                            ${kcSanitize(messagesPerField.get('password'))?no_esc}
                        </span>
                    </#if>
                </div>

                <div class="mb3">
                    <label for="password-confirm" class="f4 db b mb2">
                        ${msg("passwordConfirm")}
                    </label>
                    <div>
                        <input class="form-control w-100" type="password" id="password-confirm" name="password-confirm"
                                autocomplete="new-password"
                                aria-invalid="<#if messagesPerField.existsError('password-confirm')>true</#if>"
                        />
                    </div>

                    <#if messagesPerField.existsError('password-confirm')>
                        <span id="input-error-password-confirm" class="red mb3"  aria-live="polite">
                            ${kcSanitize(messagesPerField.get('password-confirm'))?no_esc}
                        </span>
                    </#if>
                </div>

                <div class="mb3">
                    <@passwordCommons.logoutOtherSessions/>
                </div>

                <div id="kc-form-buttons" class="${properties.kcFormButtonsClass!} pf-m-action">
                    <div class="pf-v5-c-form__actions">
                        <#if isAppInitiatedAction??>
                            <input class="${properties.kcButtonClass!} ${properties.kcButtonPrimaryClass!} ${properties.kcButtonLargeClass!}" type="submit" value="${msg("doSubmit")}" />
                            <button class="${properties.kcButtonClass!} ${properties.kcButtonDefaultClass!} ${properties.kcButtonLargeClass!}" type="submit" name="cancel-aia" value="true" />${msg("doCancel")}</button>
                        <#else>
                            <input class="${properties.kcButtonClass!} ${properties.kcButtonPrimaryClass!} ${properties.kcButtonBlockClass!} ${properties.kcButtonLargeClass!}" type="submit" value="${msg("doSubmit")}" />
                        </#if>
                    </div>
                </div>
            </form>
        </div>
        </div>
        <script type="module" src="${url.resourcesPath}/js/passwordVisibility.js"></script>
    </#if>
</@layout.registrationLayout>
