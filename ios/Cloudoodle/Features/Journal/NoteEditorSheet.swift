import SwiftUI

/// The "back of the Polaroid" — a writing surface that shows the
/// front of the Polaroid as a small thumbnail at the top so the user
/// remembers which moment they're annotating, with the note editor
/// below. Used from both today's view and the gallery.
///
/// The cream sheet background matches a Polaroid's actual back-paper
/// color, reinforcing the "flipping the photo over to write on it"
/// metaphor. The shadow on the thumbnail does the work of separating
/// it from the same-color sheet.
struct NoteEditorSheet: View {
    let entry: JournalEntry

    @AppStorage("polaroid_show_shape_caption") private var showShapeCaption = true

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                PolaroidCard(
                    entry: entry,
                    showShapeCaption: showShapeCaption,
                    tilt: 0
                )
                .frame(maxWidth: 180)
                .frame(maxWidth: .infinity)

                JournalNoteEditor(entryId: entry.id, initial: entry.note)
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
            .padding(.bottom, 30)
        }
        .background(Color(red: 0.97, green: 0.96, blue: 0.93))
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
