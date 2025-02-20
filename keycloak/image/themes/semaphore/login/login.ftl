<#import "template.ftl" as layout>
<@layout.registrationLayout displayMessage=!messagesPerField.existsError('username','password') displayInfo=realm.password && realm.registrationAllowed && !registrationDisabled??; section>
    <#if section = "form">
    <div class="tc mt6 mb4">
        <img decoding="async" width="164" height="23" src="https://semaphoreci.com/wp-content/uploads/2024/04/semaphore-logo.svg" alt="" class="wp-image-23606">
    </div>
    <div class="mw6 center br4 pa4" style="background:linear-gradient(43deg,rgb(199,218,255) 0%,rgb(194,240,215) 100%);">
        <div class="bg-white ba pa3 br4" style="border-color: #ccc;">
            <div class="gray tc f4 mt2">
                Log in to Semaphore
            </div>
            <#if realm.password>
                <form id="kc-form-login" class="pa3 ${properties.kcFormClass!} onsubmit="login.disabled = true; return true;" action="${url.loginAction}" method="post">
                    <#if !usernameHidden??>
                        <div class="mb3">
                            <label for="username" class="f4 db b mb2">
                                <span class="pf-v5-c-form__label-text">
                                    ${msg("email")}
                                </span>
                            </label>

                            <span class="${properties.kcInputClass!} ${messagesPerField.existsError('username','password')?then('pf-m-error', '')}">
                                <input class="form-control w-100" tabindex="1" id="username" name="username" value="${(login.username!'')}" type="text" autofocus autocomplete="off" aria-invalid="<#if messagesPerField.existsError('username','password')>true</#if>"/>
                            </span>
                        </div>
                    </#if>

                    <div class="mb3">
                        <label for="password" class="f4 db b mb2">
                            <span class="pf-v5-c-form__label-text">${msg("password")}</span>
                        </label>
                        <div>
                            <input class="form-control w-100" tabindex="2" id="password" name="password" type="password" autocomplete="off" aria-invalid="<#if messagesPerField.existsError('username','password')>true</#if>"/>
                        </div>
                    </div>

                    <div class="${properties.kcFormGroupClass!} ${properties.kcFormSettingClass!}">
                        <div id="kc-form-options">
                            <#if realm.rememberMe && !usernameHidden??>
                                <div class="checkbox">
                                    <label>
                                        <span class="pf-v5-c-form__label-text">
                                        <#if login.rememberMe??>
                                            <input tabindex="3" id="rememberMe" name="rememberMe" type="checkbox" checked> ${msg("rememberMe")}
                                        <#else>
                                            <input tabindex="3" id="rememberMe" name="rememberMe" type="checkbox"> ${msg("rememberMe")}
                                        </#if>
                                        </span>
                                    </label>
                                </div>
                            </#if>
                            </div>
                            <div class="${properties.kcFormOptionsWrapperClass!}">
                                <#if realm.resetPasswordAllowed>
                                    <span><a tabindex="5" href="${url.loginResetCredentialsUrl}">${msg("doForgotPassword")}</a></span>
                                </#if>
                            </div>

                        </div>

                        <#if messagesPerField.existsError('username','password')>
                            <div class="red mb3" aria-live="polite">
                                ${kcSanitize(messagesPerField.getFirstError('username','password'))?no_esc}
                            </div>
                        </#if>

                        <div id="kc-form-buttons" class="${properties.kcFormGroupClass!}">
                            <input type="hidden" id="id-hidden-input" name="credentialId" <#if auth.selectedCredential?has_content>value="${auth.selectedCredential}"</#if>/>
                            <input tabindex="4" class="${properties.kcButtonClass!} ${properties.kcButtonPrimaryClass!} ${properties.kcButtonBlockClass!} ${properties.kcButtonLargeClass!}" name="login" id="kc-login" type="submit" value="${msg("doLogIn")}"/>
                        </div>
                </form>
            </#if>
        </div>
    </div>
    </#if>

</@layout.registrationLayout>
