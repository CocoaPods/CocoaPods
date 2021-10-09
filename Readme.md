Logotipo de CocoaPods
CocoaPods: el administrador de dependencias de Cocoa
Estado de la construcción Versión de gema Mantenibilidad Cobertura de prueba

CocoaPods administra las dependencias para sus proyectos de Xcode.

Usted especifica las dependencias para su proyecto en un archivo de texto simple: su Podfile. CocoaPods resuelve de forma recursiva las dependencias entre bibliotecas, recupera el código fuente para todas las dependencias y crea y mantiene un espacio de trabajo de Xcode para construir su proyecto. Se admiten las últimas versiones de Xcode publicadas y la versión anterior.

Instalar y actualizar CocoaPods es muy sencillo. No se pierda la guía de instalación y la guía de introducción .

Objetivos del proyecto
CocoaPods tiene como objetivo mejorar el compromiso y la capacidad de descubrimiento de bibliotecas Cocoa de código abierto de terceros. Estos objetivos del proyecto influyen e impulsan el diseño de CocoaPods:

Cree y comparta bibliotecas y utilícelas en sus propios proyectos, sin crear trabajo adicional para los autores de bibliotecas. Integre bibliotecas que no sean de CocoaPods y piratee en su propia bifurcación de cualquier biblioteca de CocoaPods con un Podspecestándar transparente simple .
Permita que los autores de bibliotecas estructuran sus bibliotecas como quieran.
Ahorre tiempo para los autores de bibliotecas automatizando gran parte del trabajo de Xcode no relacionado con la funcionalidad de sus bibliotecas.
Admite cualquier sistema de gestión de fuentes. (Actualmente están soportados git, svn, mercurial, bazaar, y varios tipos de archivos descargados a través de HTTP.)
Promueva una cultura de colaboración distribuida en pods, pero también proporcione características que solo son posibles con una solución centralizada para fomentar una comunidad.
Cree herramientas sobre el sistema de desarrollo central de Cocoa, incluidas las que se implementan normalmente en otros sistemas operativos, como los servicios web.
Proporcione una integración obstinada y automatizada, pero hágalo completamente opcional. Puede integrar manualmente sus dependencias de CocoaPods en su proyecto de Xcode como mejor le parezca, con o sin un espacio de trabajo.
Resuelva los problemas cotidianos para los desarrolladores de Cocoa y Xcode.
Patrocinadores
Patrocinado con amor por una colección de empresas, consulte el pie de página de CocoaPods.org para obtener una lista actualizada.

Colaborar
Todo el desarrollo de CocoaPods ocurre en GitHub. Las contribuciones generan un buen karma y damos la bienvenida a los nuevos colaboradores con alegría. Nos tomamos en serio a los colaboradores y, por lo tanto, tenemos un código de conducta para colaboradores .

Enlaces
Enlace	Descripción
CocoaPods.org	Página de inicio y búsqueda de pods.
@CocoaPods	Siga CocoaPods en Twitter para mantenerse actualizado.
Blog	El blog de CocoaPods.
Lista de correo	No dude en hacer cualquier tipo de pregunta.
Guías	Todo lo que quieres saber sobre CocoaPods.
Registro de cambios	Vea los cambios introducidos en cada versión de CocoaPods.
Nuevos pods RSS	No te pierdas ningún Pods nuevo.
Código de conducta	Descubra los estándares a los que nos adherimos.
Proyectos
CocoaPods se compone de los siguientes proyectos:

Estado	Proyecto	Descripción	Información
Estado de la construcción	CocoaPods	La herramienta de línea de comandos CocoaPods.	guías
Estado de la construcción	Núcleo de CocoaPods	Soporte para trabajar con especificaciones y podfiles.	docs
Estado de la construcción	Descargador de CocoaPods	Descargadores para varios tipos de fuentes.	docs
Estado de la construcción	Xcodeproj	Crea y modifica proyectos de Xcode desde Ruby.	docs
Estado de la construcción	CLAide	Un pequeño marco de interfaz de línea de comandos.	docs
Estado de la construcción	Molinillo	Un potente solucionador de dependencias genérico.	docs
Master Repo	Repositorio maestro de especificaciones.	guías
