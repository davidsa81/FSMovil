#!/usr/bin/env python3
"""
Ajusta la carpeta android/ que genera `flutter create` (se regenera en cada compilación,
así siempre coincide con la versión de Flutter usada). Se puede ejecutar varias veces.

- Permisos (internet, cámara, notificaciones), nombre "FSMovil", tráfico http permitido
  (hay FacturaScripts en redes locales sin https) y consultas para abrir teléfono y mapas.
- minSdk 24 (Android 7) y firma con la clave de android/key.properties si existe.
- Iconos de tool/iconos.
"""
import os
import re
import shutil
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANDROID = os.path.join(RAIZ, 'android')


def leer(ruta):
    with open(ruta, encoding='utf-8') as f:
        return f.read()


def escribir(ruta, texto):
    with open(ruta, 'w', encoding='utf-8') as f:
        f.write(texto)


def manifiesto():
    ruta = os.path.join(ANDROID, 'app', 'src', 'main', 'AndroidManifest.xml')
    m = leer(ruta)

    permisos = [
        'android.permission.INTERNET',
        'android.permission.CAMERA',
        'android.permission.POST_NOTIFICATIONS',
    ]
    for p in permisos:
        if p not in m:
            m = re.sub(r'(<manifest[^>]*>)', r'\1\n    <uses-permission android:name="%s"/>' % p, m, count=1)

    m = re.sub(r'android:label="[^"]*"', 'android:label="FSMovil"', m, count=1)
    if 'usesCleartextTraffic' not in m:
        m = m.replace('<application', '<application\n        android:usesCleartextTraffic="true"', 1)

    consultas = '''
        <intent>
            <action android:name="android.intent.action.DIAL"/>
            <data android:scheme="tel"/>
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW"/>
            <data android:scheme="https"/>
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW"/>
            <data android:scheme="geo"/>
        </intent>'''
    if 'android.intent.action.DIAL' not in m:
        if '<queries>' in m:
            m = m.replace('<queries>', '<queries>' + consultas, 1)
        else:
            m = m.replace('</manifest>', '    <queries>' + consultas + '\n    </queries>\n</manifest>', 1)

    escribir(ruta, m)
    print('AndroidManifest.xml ajustado')


FIRMA_KTS_IMPORTS = '''import java.io.FileInputStream
import java.util.Properties

'''

FIRMA_KTS_CABECERA = '''val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

'''

FIRMA_KTS_BLOQUE = '''    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

'''

FIRMA_GROOVY_CABECERA = '''def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

'''

FIRMA_GROOVY_BLOQUE = '''    signingConfigs {
        release {
            if (keystorePropertiesFile.exists()) {
                keyAlias keystoreProperties['keyAlias']
                keyPassword keystoreProperties['keyPassword']
                storeFile file(keystoreProperties['storeFile'])
                storePassword keystoreProperties['storePassword']
            }
        }
    }

'''


def gradle():
    kts = os.path.join(ANDROID, 'app', 'build.gradle.kts')
    groovy = os.path.join(ANDROID, 'app', 'build.gradle')
    if os.path.exists(kts):
        g = leer(kts)
        if 'keystorePropertiesFile' not in g:
            # los import van arriba del todo; el resto, después del bloque plugins {} (justo antes de android {})
            g = FIRMA_KTS_IMPORTS + g
            g = re.sub(r'(\nandroid\s*\{)', '\n' + FIRMA_KTS_CABECERA.rstrip('\n') + '\n' + r'\1', g, count=1)
            g = re.sub(r'(\n\s*buildTypes\s*\{)', '\n' + FIRMA_KTS_BLOQUE.rstrip('\n') + r'\1', g, count=1)
            g = re.sub(
                r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)',
                'signingConfig = if (keystorePropertiesFile.exists()) signingConfigs.getByName("release") '
                'else signingConfigs.getByName("debug")',
                g,
            )
        g = re.sub(r'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = maxOf(24, flutter.minSdkVersion)', g)
        escribir(kts, g)
        print('build.gradle.kts ajustado')
    elif os.path.exists(groovy):
        g = leer(groovy)
        if 'keystorePropertiesFile' not in g:
            g = re.sub(r'(\nandroid\s*\{)', '\n' + FIRMA_GROOVY_CABECERA.rstrip('\n') + r'\1', g, count=1)
            g = re.sub(r'(\n\s*buildTypes\s*\{)', '\n' + FIRMA_GROOVY_BLOQUE.rstrip('\n') + r'\1', g, count=1)
            g = re.sub(
                r'signingConfig\s*=?\s*signingConfigs\.debug',
                'signingConfig keystorePropertiesFile.exists() ? signingConfigs.release : signingConfigs.debug',
                g,
            )
        g = re.sub(r'minSdkVersion\s+flutter\.minSdkVersion', 'minSdkVersion Math.max(24, flutter.minSdkVersion)', g)
        g = re.sub(r'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = Math.max(24, flutter.minSdkVersion)', g)
        escribir(groovy, g)
        print('build.gradle ajustado')
    else:
        sys.exit('No se encuentra android/app/build.gradle(.kts)')


GOOGLE_SERVICES_VERSION = '4.4.2'


def firebase():
    """Si hay google-services.json (lo pone el workflow desde un secreto), activa el plugin de Google Services."""
    if not os.path.exists(os.path.join(ANDROID, 'app', 'google-services.json')):
        print('Sin google-services.json: la app se compila sin notificaciones push')
        return

    ajustes_kts = os.path.join(ANDROID, 'settings.gradle.kts')
    ajustes_groovy = os.path.join(ANDROID, 'settings.gradle')
    app_kts = os.path.join(ANDROID, 'app', 'build.gradle.kts')
    app_groovy = os.path.join(ANDROID, 'app', 'build.gradle')

    if os.path.exists(ajustes_kts):
        a = leer(ajustes_kts)
        if 'com.google.gms.google-services' not in a:
            a, n = re.subn(
                r'(\n(\s*)id\("com\.android\.application"\)[^\n]*)',
                r'\1\n\2id("com.google.gms.google-services") version "%s" apply false' % GOOGLE_SERVICES_VERSION,
                a, count=1)
            if n == 0:
                sys.exit('No se pudo añadir el plugin de Google Services a settings.gradle.kts')
            escribir(ajustes_kts, a)
    elif os.path.exists(ajustes_groovy):
        a = leer(ajustes_groovy)
        if 'com.google.gms.google-services' not in a:
            a, n = re.subn(
                r'(\n(\s*)id\s+"com\.android\.application"[^\n]*)',
                r'\1\n\2id "com.google.gms.google-services" version "%s" apply false' % GOOGLE_SERVICES_VERSION,
                a, count=1)
            if n == 0:
                sys.exit('No se pudo añadir el plugin de Google Services a settings.gradle')
            escribir(ajustes_groovy, a)

    if os.path.exists(app_kts):
        g = leer(app_kts)
        if 'com.google.gms.google-services' not in g:
            g, n = re.subn(r'(plugins\s*\{[^}]*?)(\n\})', r'\1\n    id("com.google.gms.google-services")\2', g, count=1)
            if n == 0:
                sys.exit('No se pudo añadir el plugin de Google Services a app/build.gradle.kts')
            escribir(app_kts, g)
    elif os.path.exists(app_groovy):
        g = leer(app_groovy)
        if 'com.google.gms.google-services' not in g:
            g, n = re.subn(r'(plugins\s*\{[^}]*?)(\n\})', r'\1\n    id "com.google.gms.google-services"\2', g, count=1)
            if n == 0:
                sys.exit('No se pudo añadir el plugin de Google Services a app/build.gradle')
            escribir(app_groovy, g)
    print('Firebase activado (plugin de Google Services)')


def iconos():
    origen = os.path.join(RAIZ, 'tool', 'iconos')
    res = os.path.join(ANDROID, 'app', 'src', 'main', 'res')
    for carpeta in os.listdir(origen):
        destino = os.path.join(res, carpeta)
        os.makedirs(destino, exist_ok=True)
        shutil.copy(os.path.join(origen, carpeta, 'ic_launcher.png'), os.path.join(destino, 'ic_launcher.png'))
    print('Iconos copiados')


if __name__ == '__main__':
    if not os.path.isdir(ANDROID):
        sys.exit('Falta la carpeta android/: ejecuta antes flutter create')
    manifiesto()
    gradle()
    firebase()
    iconos()
