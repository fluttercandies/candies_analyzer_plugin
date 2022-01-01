// void findReference(
//     Reference? reference,
//     bool Function(Element element) find,
//     Set<Reference> caches, {
//     String? path,
//   }) {
//     if (reference == null) {
//       return;
//     }
//     if (caches.contains(reference)) {
//       return;
//     }

//     caches.add(reference);

//     final Element? element = reference.element;

//     // not find reference not in path file
//     if (path != null && element != null && element.source?.fullName != path) {
//       return;
//     }

//     if (element != null) {
//       find(element);
//     }

//     for (final Reference child in reference.children) {
//       findReference(child, find, caches, path: path);
//     }

//     findReference(reference.parent, find, caches, path: path);
//   }
