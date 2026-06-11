import Foundation

struct ExerciseSearchAliases {
    static func bodyRegionTerms(for muscleGroups: [MuscleGroup]) -> [String] {
        let uniqueGroups = Set(muscleGroups)
        var terms = Set<String>()

        let lowerBodyGroups: Set<MuscleGroup> = [.quadriceps, .hamstrings, .glutes, .calves]
        let upperBodyGroups: Set<MuscleGroup> = [.chest, .back, .shoulders, .biceps, .triceps, .forearms, .traps]
        let coreGroups: Set<MuscleGroup> = [.abs, .obliques, .lowerBack]
        let armGroups: Set<MuscleGroup> = [.biceps, .triceps, .forearms]
        let pushGroups: Set<MuscleGroup> = [.chest, .shoulders, .triceps]
        let pullGroups: Set<MuscleGroup> = [.back, .biceps, .forearms, .traps]

        let matchesLowerBody = !uniqueGroups.isDisjoint(with: lowerBodyGroups)
        let matchesUpperBody = !uniqueGroups.isDisjoint(with: upperBodyGroups)
        let matchesCore = !uniqueGroups.isDisjoint(with: coreGroups)

        if matchesLowerBody {
            terms.formUnion(["lower body", "leg", "legs"])
        }

        if matchesUpperBody {
            terms.insert("upper body")
        }

        if !uniqueGroups.isDisjoint(with: armGroups) {
            terms.formUnion(["arm", "arms"])
        }

        if !uniqueGroups.isDisjoint(with: pushGroups) {
            terms.formUnion(["push", "push day"])
        }

        if !uniqueGroups.isDisjoint(with: pullGroups) {
            terms.formUnion(["pull", "pull day"])
        }

        if matchesCore {
            terms.insert("core")
        }

        if (matchesUpperBody && matchesLowerBody) || (matchesCore && (matchesUpperBody || matchesLowerBody)) {
            terms.formUnion(["full body", "total body"])
        }

        return terms.sorted()
    }
}
